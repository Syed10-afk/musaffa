# Downloads every referenced /assets/* and chunk JS files referenced in index.html
# Saves assets to assets/... and JS chunks to chunks/...

$index = "index.html"
$backup = "index.html.bak"
if (Test-Path $backup) { Remove-Item $backup -Force }
Copy-Item -Path $index -Destination $backup -Force

$html = Get-Content -LiteralPath $index -Raw

$matches = @()
# find full https musaffa assets
$matches += [regex]::Matches($html, 'https?:\\/\\/musaffa.com\\/assets\\/[^"\'\s>]+') | ForEach-Object { $_.Value }
# find /assets/ occurrences
$matches += [regex]::Matches($html, '\/assets\/[^")\'\s>]+') | ForEach-Object { $_.Value }
# find chunk and JS filenames referenced (chunk-*.js, main-*.js, polyfills-*.js)
$matches += [regex]::Matches($html, '(?:chunk|main|polyfills)[^"\'\s>]*?\.js') | ForEach-Object { $_.Value }

$matches = $matches | Sort-Object -Unique

$log = @()

foreach ($m in $matches) {
    $url = $m
    if ($url -like '/assets/*') { $url = "https://musaffa.com" + $url }
    elseif ($url -notmatch '^https?://') {
        # assume root-hosted JS chunk
        $url = "https://musaffa.com/" + $url
    }
    # determine local path
    if ($url -match '/assets/(.+)$') {
        $rel = $matches[0] # dummy to avoid pipeline
    }
    $relPath = $null
    if ($url -match '/assets/(.+)$') { $relPath = $Matches[1].Replace('%20',' '); $local = Join-Path "assets" $relPath }
    else {
        # put JS files under chunks/
        $fname = Split-Path $url -Leaf
        $local = Join-Path "chunks" $fname
    }
    $localDir = Split-Path $local -Parent
    if (!(Test-Path $localDir)) { New-Item -ItemType Directory -Path $localDir -Force | Out-Null }
    try {
        Invoke-WebRequest -Uri $url -OutFile $local -UseBasicParsing -ErrorAction Stop
        $log += "OK: $url -> $local"
    } catch {
        $log += "FAIL: $url : $($_.Exception.Message)"
    }
}
# rewrite index.html to point to local files
$html = $html -replace 'https?://musaffa.com/assets/','assets/'
# update /assets/ occurrences too
$html = $html -replace '/assets/','assets/'
# rewrite JS filenames to chunks/
$html = [regex]::Replace($html, '((?:chunk|main|polyfills)[^"\'\s>]*?\.js)', 'chunks/$1')

Set-Content -LiteralPath $index -Value $html -Encoding UTF8

# save log
$log | Out-File -FilePath download-assets.log -Encoding utf8
Write-Output "Download complete. See download-assets.log for details."
