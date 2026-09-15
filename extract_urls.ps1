$index = 'index.html'
$html = Get-Content -LiteralPath $index -Raw
$set = New-Object System.Collections.Generic.HashSet[string]
foreach ($m in [regex]::Matches($html, 'https?://musaffa.com/assets/[^"'"'\s>]+')) { $set.Add($m.Value) | Out-Null }
foreach ($m in [regex]::Matches($html, '/assets/[^"'"'\s>]+')) { $set.Add('https://musaffa.com' + $m.Value) | Out-Null }
foreach ($m in [regex]::Matches($html, '(?:chunk|main|polyfills)[^"'"'\s>]*?\.js')) { $set.Add('https://musaffa.com/' + $m.Value) | Out-Null }
$set | Sort-Object | Out-File -FilePath urls-to-download.txt -Encoding utf8
Write-Output ("Wrote {0} URLs to urls-to-download.txt" -f $set.Count)
