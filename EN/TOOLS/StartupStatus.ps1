$os=Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$net=if(Test-NetConnection 1.1.1.1 -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue){'CONNECTED'}else{'NO CONNECTION'}
$pending=$false
$keys=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
foreach($k in $keys){if(Test-Path $k){$pending=$true}}
'DATE|'+(Get-Date -Format 'dd/MM/yyyy'); 'TIME|'+(Get-Date -Format 'HH:mm:ss'); 'WINDOWS|'+$os.Caption; 'INTERNET|'+$net; 'REBOOT|'+$(if($pending){'YES'}else{'NO'})
