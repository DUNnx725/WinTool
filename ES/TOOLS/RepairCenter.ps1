param(
 [ValidateSet('Check','DISM','SFC','Network','WinGet')] [string]$Mode='Check',
 [string]$OutFile=''
)
$ErrorActionPreference='Continue'
function Log($s){Write-Host $s; if($OutFile){Add-Content -LiteralPath $OutFile -Value $s -Encoding UTF8}}
if($OutFile){Set-Content -LiteralPath $OutFile -Value ("CENTRO DE REPARACIONES`r`n"+(Get-Date)) -Encoding UTF8}
switch($Mode){
 'Check' {
   Log 'DIAGNOSTICO DE REPARACION'
   $pending=$false
   foreach($p in @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
   )){if(Test-Path $p){$pending=$true}}
   Log ("Reinicio pendiente: "+$(if($pending){'SI'}else{'NO'}))
   $wu=Get-Service wuauserv -ErrorAction SilentlyContinue
   Log ("Windows Update: "+$(if($wu){$wu.Status}else{'NO DETECTADO'}))
   $wg=Get-Command winget.exe -ErrorAction SilentlyContinue
   Log ("WinGet: "+$(if($wg){'DISPONIBLE'}else{'NO DISPONIBLE'}))
   try{$net=Test-NetConnection 1.1.1.1 -InformationLevel Quiet -WarningAction SilentlyContinue}catch{$net=$false}
   Log ("Internet: "+$(if($net){'OK'}else{'REVISAR'}))
   Log ''
   Log 'Esto solo diagnostica. Usa una reparacion concreta si existe un problema real.'
 }
 'DISM' {
   Log 'Ejecutando DISM RestoreHealth. Microsoft recomienda DISM antes de SFC cuando hay corrupcion.'
   & DISM.exe /Online /Cleanup-Image /RestoreHealth
   exit $LASTEXITCODE
 }
 'SFC' {
   Log 'Ejecutando SFC /scannow.'
   & sfc.exe /scannow
   exit $LASTEXITCODE
 }
 'Network' {
   Log 'REPARACION DE RED'
   Log 'Se vaciara cache DNS y se renovara DHCP. Winsock/TCP NO se resetean automaticamente.'
   ipconfig /flushdns | Out-Host
   ipconfig /renew | Out-Host
   Log 'Completado. Si el problema continua, usa el solucionador de Windows o revisa el adaptador.'
 }
 'WinGet' {
   $wg=Get-Command winget.exe -ErrorAction SilentlyContinue
   if(-not $wg){Log '[REVISAR] WinGet no esta disponible. Abriendo Microsoft Store > App Installer.'; Start-Process 'ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1'; exit 2}
   Log ('WinGet detectado: '+(& winget --version))
   Log 'Mostrando fuentes configuradas:'
   & winget source list
 }
}
exit 0
