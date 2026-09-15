<#
Builds a URL list from index.html, downloads files to `assets/` and `chunks/`,
and rewrites `index.html` to use local `assets/` and `chunks/` paths.
#>

$index = 'index.html'
$urlsFile = 'urls-to-download.txt'
$logFile = 'download-assets.log'

if (!(Test-Path $index)) {
    Write-Error "index.html not found in the current folder"
    exit 1
}

if (Test-Path $urlsFile) { Remove-Item $urlsFile -Force }
if (Test-Path $logFile) { Remove-Item $logFile -Force }

$html = Get-Content -LiteralPath $index -Raw

$collector = New-Object System.Collections.Generic.List[string]

# absolute musaffa assets and assets referenced with leading slash
[regex]::Matches($html, 'https?://musaffa.com/assets/[^"'"'\s>]+') | ForEach-Object { if (-not $collector.Contains($_.Value)) { $collector.Add($_.Value) } }
[regex]::Matches($html, '/assets/[^"'"'\s>]+') | ForEach-Object { $u = 'https://musaffa.com' + $_.Value; if (-not $collector.Contains($u)) { $collector.Add($u) } }

# other absolute musaffa URLs (images/fonts/pdf/js/css) under root
[regex]::Matches($html, 'https?://musaffa.com/[^"'"'\s>]+\.(?:webp|png|jpg|jpeg|svg|woff2|woff|pdf|js|css)') | ForEach-Object { if (-not $collector.Contains($_.Value)) { $collector.Add($_.Value) } }

# also collect root-anchored files like /favicon, /assets already covered
[regex]::Matches($html, '/[^"'"'\s>]+\.(?:webp|png|jpg|jpeg|svg|woff2|woff|pdf|js|css)') | ForEach-Object { $u = $_.Value; if ($u.StartsWith('/')) { $u = 'https://musaffa.com' + $u } if (-not $collector.Contains($u) -and $u -match '^https?://musaffa.com/') { $collector.Add($u) } }

$collector = $collector | Sort-Object -Unique

if ($collector.Count -eq 0) {
    Write-Output "No remote musaffa URLs found in index.html"
    exit 0
}

$collector | Out-File -FilePath $urlsFile -Encoding utf8
Write-Output "Wrote $($collector.Count) URLs to $urlsFile"

# create folders
if (!(Test-Path 'assets')) { New-Item -ItemType Directory -Path 'assets' | Out-Null }
if (!(Test-Path 'chunks')) { New-Item -ItemType Directory -Path 'chunks' | Out-Null }

$log = New-Object System.Collections.Generic.List[string]

foreach ($u in $collector) {
    try {
        if ($u -match 'https?://musaffa.com/assets/(.+)$') {
            $rel = $Matches[1]
            $local = Join-Path 'assets' $rel
        } elseif ($u -match 'https?://musaffa.com/(.+\.(?:js))$') {
            $fname = $Matches[1]
            $local = Join-Path 'chunks' $fname
        } else {
            # default to assets/
            $pathPart = $u -replace '^https?://musaffa.com/', ''
            $local = Join-Path 'assets' $pathPart
        }

        $localDir = Split-Path $local -Parent
        if (!(Test-Path $localDir)) { New-Item -ItemType Directory -Path $localDir -Force | Out-Null }

        Write-Output "Downloading $u -> $local"
        Invoke-WebRequest -Uri $u -OutFile $local -UseBasicParsing -ErrorAction Stop
        $log.Add("OK: $u -> $local")
    } catch {
        $err = $_.Exception.Message -replace "\r|\n"," "
        $log.Add("FAIL: $u : $err")
    }
}

# rewrite index.html: point musaffa.com/assets/... -> assets/ and other root files to assets/
$indexHtml = Get-Content -LiteralPath $index -Raw
$indexHtml = $indexHtml -replace 'https?://musaffa.com/assets/','assets/'
$indexHtml = $indexHtml -replace '/assets/','assets/'
$indexHtml = [regex]::Replace($indexHtml, 'https?://musaffa.com/((?:chunk|main|polyfills)[^"'"'\s>]*)', 'chunks/$1')

Set-Content -LiteralPath $index -Value $indexHtml -Encoding UTF8

$log | Out-File -FilePath $logFile -Encoding utf8
Write-Output "Download finished. See $logFile for details."
