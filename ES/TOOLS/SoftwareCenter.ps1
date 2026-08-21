param([ValidateSet('Check','UpgradeAll','OpenInstalled')] [string]$Mode='Check')
$wg=Get-Command winget.exe -ErrorAction SilentlyContinue
if(-not $wg){
 Write-Host '[NO DISPONIBLE] WinGet no esta instalado o no esta en PATH.'
 Write-Host 'Puedes instalar/actualizar App Installer desde Microsoft Store.'
 exit 2
}
switch($Mode){
 'Check' {
  Write-Host 'ACTUALIZACIONES DISPONIBLES'
  Write-Host ''
  & winget upgrade --accept-source-agreements
 }
 'UpgradeAll' {
  Write-Host 'WinGet actualizara paquetes que tengan una actualizacion aplicable.'
  & winget upgrade --all --accept-source-agreements --accept-package-agreements
 }
 'OpenInstalled' { Start-Process 'ms-settings:appsfeatures' }
}
exit $LASTEXITCODE
