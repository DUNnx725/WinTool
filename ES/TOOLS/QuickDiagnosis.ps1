param([string]$OutFile="")
$ErrorActionPreference='SilentlyContinue'
Write-Host "Midiendo el equipo durante 8 segundos..."
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
$lines=@('QUE ESTA RALENTIZANDO MI PC?','')
$lines+=('CPU promedio........ {0:N1} %%' -f $cpuAvg)
$lines+=('Disco promedio...... {0:N1} %%' -f $diskAvg)
$lines+=('RAM actual.......... {0} %%' -f $ramPct)
$lines+=('Entradas de inicio.. {0}' -f $startup)
$lines+=('Espacio libre C:.... {0} %%' -f $freePct)
$lines+=('WHEA importantes.... {0}' -f $wheaBad.Count)
$lines+=('WHEA informativos... {0}' -f $wheaInfo.Count)
$lines+='';$lines+='RECOMENDACIONES'
$found=$false
if($ramPct -ge 85){$lines+='[REVISAR] RAM muy ocupada en esta medicion.';$found=$true}
if($cpuAvg -ge 60){$lines+='[REVISAR] CPU sostenida alta durante la muestra.';$found=$true}
if($diskAvg -ge 70){$lines+='[REVISAR] Actividad de disco alta durante la muestra.';$found=$true}
if($startup -ge 12){$lines+='[INFO] Hay bastantes entradas de inicio; revisarlas puede ayudar al arranque.'}
if($freePct -lt 15){$lines+='[REVISAR] Poco espacio libre en C:.';$found=$true}
if($wheaBad.Count -gt 0){$lines+='[REVISAR] Hay WHEA de advertencia/error recientes; revisar estabilidad.';$found=$true}
elseif($wheaInfo.Count -gt 0){$lines+='[INFO] Solo hay WHEA informativos; no se consideran una falla.'}
if(-not $found){$lines+='[OK] No aparece un cuello de botella obvio en esta muestra corta.'}
$lines+='';$lines+='PROCESOS CON MAYOR CPU ACUMULADA'
foreach($p in $top){$lines+=('{0,-28} CPU {1,8:N1}s  RAM {2,7:N0} MB' -f $p.Name,$p.CPU,($p.WorkingSet64/1MB))}
$lines|ForEach-Object{Write-Host $_}
if($OutFile){$lines|Set-Content -LiteralPath $OutFile -Encoding UTF8}
exit 0
