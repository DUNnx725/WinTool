param([string]$OutFile="")
$ErrorActionPreference='SilentlyContinue'
function Bar([double]$pct){
    $pct=[math]::Max(0,[math]::Min(100,$pct));$n=[int]($pct/5)
    return ('['+('='*$n)+('.'*(20-$n))+('] {0,3} %' -f [int]$pct))
}
$os=Get-CimInstance Win32_OperatingSystem
$cs=Get-CimInstance Win32_ComputerSystem
$cpu=Get-CimInstance Win32_Processor|Select-Object -First 1
$gpu=Get-CimInstance Win32_VideoController|Where-Object {$_.Name -notmatch 'Basic Display'}|Select-Object -First 1
$bios=Get-CimInstance Win32_BIOS
$sysDrive=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$cpuLoad=[double]$cpu.LoadPercentage
$ramTotal=[math]::Round($cs.TotalPhysicalMemory/1GB,1)
$ramFree=[math]::Round($os.FreePhysicalMemory*1KB/1GB,1)
$ramUsedPct=if($ramTotal){[math]::Round((1-($ramFree/$ramTotal))*100)}else{0}
$diskUsedPct=if($sysDrive.Size){[math]::Round((1-($sysDrive.FreeSpace/$sysDrive.Size))*100)}else{0}
$procs=@(Get-Process).Count
$services=@(Get-Service|Where-Object Status -eq 'Running').Count
$uptime=(Get-Date)-$os.LastBootUpTime
$net='DISCONNECTED'
try{if(Test-NetConnection 1.1.1.1 -InformationLevel Quiet -WarningAction SilentlyContinue){$net='CONNECTED'}}catch{}

$wheaBad=0;$wheaInfo=0
try{
    $w=@(Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-WHEA-Logger';StartTime=(Get-Date).AddDays(-7)})
    $wheaBad=@($w|Where-Object {$_.Level -in 1,2,3}).Count
    $wheaInfo=@($w|Where-Object {$_.Level -eq 4 -or $_.LevelDisplayName -match 'Information|Informacion|Información'}).Count
}catch{}

$lines=@()
$lines+='PC STATUS'
$lines+=('Date          {0}' -f (Get-Date -Format 'dd/MM/yyyy HH:mm:ss'))
$lines+=''
$lines+=('System        {0}' -f $cs.Model)
$lines+=('Processor     {0}' -f $cpu.Name.Trim())
$lines+=('Graphics       {0}' -f $(if($gpu){$gpu.Name}else{'Not detected'}))
$lines+=('Memory         {0} GB' -f $ramTotal)
$lines+=('Windows        {0} {1}  Build {2}' -f $os.Caption.Replace('Microsoft ',''),$os.OSArchitecture,$os.BuildNumber)
$lines+=('BIOS           {0}' -f $bios.SMBIOSBIOSVersion)
$lines+=('Uptime      {0:dd\.hh\:mm\:ss}' -f $uptime)
$lines+=''
$lines+='CURRENT STATUS'
$lines+=('CPU            {0}' -f (Bar $cpuLoad))
$lines+=('RAM            {0}  ({1} GB free)' -f (Bar $ramUsedPct),$ramFree)
$lines+=('Disk C:       {0}  ({1:N1} GB free)' -f (Bar $diskUsedPct),($sysDrive.FreeSpace/1GB))
$lines+=('Processes      {0}' -f $procs)
$lines+=('Services       {0} running' -f $services)
$lines+=('Internet       {0}' -f $net)
$lines+=''
$lines+='QUICK READ'
$lines+=$(if($ramUsedPct -ge 85){'[CHECK] High RAM usage.'}elseif($ramUsedPct -ge 70){'[INFO] Moderate/high RAM usage.'}else{'[OK] RAM usage is normal in this measurement.'})
$lines+=$(if($diskUsedPct -ge 90){'[CHECK] C: has low free space.'}else{'[OK] C: has a reasonable amount of free space.'})
$lines+=$(if($net -eq 'CONNECTED'){'[OK] Internet available.'}else{'[CHECK] Internet connectivity could not be confirmed.'})
if($wheaBad -gt 0){$lines+=('[CHECK] WHEA: '+$wheaBad+' recent warning(s)/error(s).')}
elseif($wheaInfo -gt 0){$lines+=('[INFO] WHEA: '+$wheaInfo+' informational event(s); they are not counted as failures.')}
else{$lines+='[OK] No recent WHEA events.'}
$lines|ForEach-Object{Write-Host $_}
if($OutFile){$lines|Set-Content -LiteralPath $OutFile -Encoding UTF8}
exit 0
