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
$net='DESCONECTADO'
try{if(Test-NetConnection 1.1.1.1 -InformationLevel Quiet -WarningAction SilentlyContinue){$net='CONECTADO'}}catch{}

$wheaBad=0;$wheaInfo=0
try{
    $w=@(Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-WHEA-Logger';StartTime=(Get-Date).AddDays(-7)})
    $wheaBad=@($w|Where-Object {$_.Level -in 1,2,3}).Count
    $wheaInfo=@($w|Where-Object {$_.Level -eq 4 -or $_.LevelDisplayName -match 'Information|Informacion|Información'}).Count
}catch{}

$lines=@()
$lines+='ESTADO DE MI PC'
$lines+=('Fecha          {0}' -f (Get-Date -Format 'dd/MM/yyyy HH:mm:ss'))
$lines+=''
$lines+=('Sistema        {0}' -f $cs.Model)
$lines+=('Procesador     {0}' -f $cpu.Name.Trim())
$lines+=('Graficos       {0}' -f $(if($gpu){$gpu.Name}else{'No detectado'}))
$lines+=('Memoria        {0} GB' -f $ramTotal)
$lines+=('Windows        {0} {1}  Build {2}' -f $os.Caption.Replace('Microsoft ',''),$os.OSArchitecture,$os.BuildNumber)
$lines+=('BIOS           {0}' -f $bios.SMBIOSBIOSVersion)
$lines+=('Actividad      {0:dd\.hh\:mm\:ss}' -f $uptime)
$lines+=''
$lines+='ESTADO ACTUAL'
$lines+=('CPU            {0}' -f (Bar $cpuLoad))
$lines+=('RAM            {0}  ({1} GB libres)' -f (Bar $ramUsedPct),$ramFree)
$lines+=('Disco C:       {0}  ({1:N1} GB libres)' -f (Bar $diskUsedPct),($sysDrive.FreeSpace/1GB))
$lines+=('Procesos       {0}' -f $procs)
$lines+=('Servicios      {0} ejecutandose' -f $services)
$lines+=('Internet       {0}' -f $net)
$lines+=''
$lines+='LECTURA RAPIDA'
$lines+=$(if($ramUsedPct -ge 85){'[REVISAR] Uso de RAM alto.'}elseif($ramUsedPct -ge 70){'[INFO] Uso de RAM moderado/alto.'}else{'[OK] Uso de RAM normal en esta medicion.'})
$lines+=$(if($diskUsedPct -ge 90){'[REVISAR] C: tiene poco espacio libre.'}else{'[OK] C: conserva espacio libre razonable.'})
$lines+=$(if($net -eq 'CONECTADO'){'[OK] Internet disponible.'}else{'[REVISAR] No se pudo confirmar Internet.'})
if($wheaBad -gt 0){$lines+=('[REVISAR] WHEA: '+$wheaBad+' advertencia(s)/error(es) recientes.')}
elseif($wheaInfo -gt 0){$lines+=('[INFO] WHEA: '+$wheaInfo+' evento(s) informativo(s); no cuentan como fallo.')}
else{$lines+='[OK] Sin eventos WHEA recientes.'}
$lines|ForEach-Object{Write-Host $_}
if($OutFile){$lines|Set-Content -LiteralPath $OutFile -Encoding UTF8}
exit 0
