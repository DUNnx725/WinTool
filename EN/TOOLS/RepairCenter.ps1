param(
 [ValidateSet('Check','DISM','SFC','Network','WinGet')] [string]$Mode='Check',
 [string]$OutFile=''
)
$ErrorActionPreference='Continue'
function Log($s){Write-Host $s; if($OutFile){Add-Content -LiteralPath $OutFile -Value $s -Encoding UTF8}}
if($OutFile){Set-Content -LiteralPath $OutFile -Value ("REPAIR CENTER`r`n"+(Get-Date)) -Encoding UTF8}
switch($Mode){
 'Check' {
   Log 'REPAIR DIAGNOSTICS'
   $pending=$false
   foreach($p in @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
   )){if(Test-Path $p){$pending=$true}}
   Log ("Pending restart: "+$(if($pending){'YES'}else{'NO'}))
   $wu=Get-Service wuauserv -ErrorAction SilentlyContinue
   Log ("Windows Update: "+$(if($wu){$wu.Status}else{'NOT DETECTED'}))
   $wg=Get-Command winget.exe -ErrorAction SilentlyContinue
   Log ("WinGet: "+$(if($wg){'AVAILABLE'}else{'NOT AVAILABLE'}))
   try{$net=Test-NetConnection 1.1.1.1 -InformationLevel Quiet -WarningAction SilentlyContinue}catch{$net=$false}
   Log ("Internet: "+$(if($net){'OK'}else{'CHECK'}))
   Log ''
   Log 'This only diagnoses. Use a specific repair if there is a real problem.'
 }
 'DISM' {
   Log 'Running DISM RestoreHealth. Microsoft recommends DISM before SFC when corruption exists.'
   & DISM.exe /Online /Cleanup-Image /RestoreHealth
   exit $LASTEXITCODE
 }
 'SFC' {
   Log 'Running SFC /scannow.'
   & sfc.exe /scannow
   exit $LASTEXITCODE
 }
 'Network' {
   Log 'NETWORK REPAIR'
   Log 'DNS cache will be cleared and DHCP renewed. Winsock/TCP are NOT reset automatically.'
   ipconfig /flushdns | Out-Host
   ipconfig /renew | Out-Host
   Log 'Completed. If the problem continues, use the Windows troubleshooter or check the adapter.'
 }
 'WinGet' {
   $wg=Get-Command winget.exe -ErrorAction SilentlyContinue
   if(-not $wg){Log '[CHECK] WinGet is not available. Opening Microsoft Store > App Installer.'; Start-Process 'ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1'; exit 2}
   Log ('WinGet detected: '+(& winget --version))
   Log 'Configured sources:'
   & winget source list
 }
}
exit 0
