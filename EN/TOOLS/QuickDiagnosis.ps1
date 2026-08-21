param([string]$OutFile="")
$ErrorActionPreference='SilentlyContinue'
Write-Host "Measuring the system for 8 seconds..."
try{
    $before=Get-Counter '\Processor(_Total)\% Processor Time','\PhysicalDisk(_Total)\% Disk Time' -SampleInterval 1 -MaxSamples 8
    $cpuAvg=(($before.CounterSamples|Where-Object Path -match 'processor').CookedValue|Measure-Object -Average).Average
    $diskAvg=(($before.CounterSamples|Where-Object Path -match 'physicaldisk').CookedValue|Measure-Object -Average).Average
}catch{
    $cpuAvg=0;$diskAvg=0
}
$os=Get-CimInstance Win32_OperatingSystem
$cs=Get-CimInstance Win32_ComputerSystem
$ramPct=[math]::Round((1-(($os.FreePhysicalMemory*1KB)/$cs.TotalPhysicalMemory))*100)
$startup=@(Get-CimInstance Win32_StartupCommand).Count
$c=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$freePct=if($c.Size){[math]::Round(($c.FreeSpace/$c.Size)*100)}else{0}

$whea=@()
try{
    $whea=@(Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-WHEA-Logger';StartTime=(Get-Date).AddDays(-7)})
}catch{}
$wheaBad=@($whea|Where-Object {$_.Level -in 1,2,3})
$wheaInfo=@($whea|Where-Object {$_.Level -eq 4 -or $_.LevelDisplayName -match 'Information|Informacion|Información'})

$top=Get-Process|Sort-Object CPU -Descending|Select-Object -First 5 Name,CPU,WorkingSet64
$lines=@('WHAT IS SLOWING DOWN MY PC?','')
$lines+=('Average CPU......... {0:N1} %%' -f $cpuAvg)
$lines+=('Average disk........ {0:N1} %%' -f $diskAvg)
$lines+=('Current RAM......... {0} %%' -f $ramPct)
$lines+=('Startup entries..... {0}' -f $startup)
$lines+=('Free space on C:.... {0} %%' -f $freePct)
$lines+=('Important WHEA..... {0}' -f $wheaBad.Count)
$lines+=('Informational WHEA events... {0}' -f $wheaInfo.Count)
$lines+='';$lines+='RECOMMENDATIONS'
$found=$false
if($ramPct -ge 85){$lines+='[CHECK] RAM usage is very high in this measurement.';$found=$true}
if($cpuAvg -ge 60){$lines+='[CHECK] Sustained CPU usage was high during the sample.';$found=$true}
if($diskAvg -ge 70){$lines+='[CHECK] Disk activity was high during the sample.';$found=$true}
if($startup -ge 12){$lines+='[INFO] There are many startup entries; reviewing them may improve startup.'}
if($freePct -lt 15){$lines+='[CHECK] Low free space on C:.';$found=$true}
if($wheaBad.Count -gt 0){$lines+='[CHECK] Recent WHEA warning/error events were found; check stability.';$found=$true}
elseif($wheaInfo.Count -gt 0){$lines+='[INFO] Only informational WHEA events were found; they are not treated as a failure.'}
if(-not $found){$lines+='[OK] No obvious bottleneck appears in this short sample.'}
$lines+='';$lines+='PROCESSES WITH HIGHEST ACCUMULATED CPU'
foreach($p in $top){$lines+=('{0,-28} CPU {1,8:N1}s  RAM {2,7:N0} MB' -f $p.Name,$p.CPU,($p.WorkingSet64/1MB))}
$lines|ForEach-Object{Write-Host $_}
if($OutFile){$lines|Set-Content -LiteralPath $OutFile -Encoding UTF8}
exit 0
