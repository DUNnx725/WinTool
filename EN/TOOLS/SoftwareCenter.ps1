param([ValidateSet('Check','UpgradeAll','OpenInstalled')] [string]$Mode='Check')
$wg=Get-Command winget.exe -ErrorAction SilentlyContinue
if(-not $wg){
 Write-Host '[NOT AVAILABLE] WinGet is not installed or is not in PATH.'
 Write-Host 'You can install/update App Installer from Microsoft Store.'
 exit 2
}
switch($Mode){
 'Check' {
  Write-Host 'AVAILABLE UPDATES'
  Write-Host ''
  & winget upgrade --accept-source-agreements
 }
 'UpgradeAll' {
  Write-Host 'WinGet will update packages that have an applicable update.'
  & winget upgrade --all --accept-source-agreements --accept-package-agreements
 }
 'OpenInstalled' { Start-Process 'ms-settings:appsfeatures' }
}
exit $LASTEXITCODE
