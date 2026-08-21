param()
Write-Host 'WINUTIL - CHRIS TITUS TECH'
Write-Host ''
Write-Host 'Advanced external tool. WinTool does not track or revert changes made inside WinUtil.'
Write-Host 'The stable command published by the official project will be used.'
Write-Host ''
$ans=Read-Host 'Type OPEN to download and run WinUtil from its official source'
if($ans -ne 'OPEN'){Write-Host 'Cancelled.';exit 0}
try {
 $script=Invoke-RestMethod -Uri 'https://christitus.com/win' -UseBasicParsing
 & ([ScriptBlock]::Create($script))
 exit 0
} catch {
 Write-Host ('[ERROR] WinUtil could not be loaded: '+$_.Exception.Message)
 exit 2
}
