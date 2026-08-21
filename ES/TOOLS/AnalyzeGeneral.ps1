param([Parameter(Mandatory=$true)][string]$OutFile)
$ErrorActionPreference='SilentlyContinue'
$os=Get-CimInstance Win32_OperatingSystem
$cpu=Get-CimInstance Win32_Processor|Select-Object -First 1
$cs=Get-CimInstance Win32_ComputerSystem
$c=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$ramTotal=[math]::Round($cs.TotalPhysicalMemory/1GB,1)
$ramFree=[math]::Round($os.FreePhysicalMemory*1KB/1GB,1)
$ramPct=[math]::Round((1-($ramFree/$ramTotal))*100)
$procs=@(Get-Process).Count
$startup=@(Get-CimInstance Win32_StartupCommand).Count
$freePct=if($c.Size){[math]::Round(($c.FreeSpace/$c.Size)*100)}else{0}
$net='NO CONFIRMADO';$ping=$null
try{
 $p=Test-Connection 1.1.1.1 -Count 4 -ErrorAction Stop
 if($p){$net='OK';$ping=[math]::Round(($p|Measure-Object ResponseTime -Average).Average,1)}
}catch{}
$trim=(fsutil behavior query DisableDeleteNotify 2>$null|Out-String)
$trimOk=($trim -match 'DisableDeleteNotify\s*=\s*0')

$lines=@()
$lines+='ANALISIS GENERAL'
$lines+=('Fecha: '+(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'))
$lines+=''
$lines+='RESUMEN'
$lines+=('Windows............. '+$os.Caption.Replace('Microsoft ',''))
$lines+=('Procesador.......... '+$cpu.Name.Trim())
$lines+=('Memoria............. '+$ramTotal+' GB | '+$ramPct+'% en uso')
$lines+=('Procesos............ '+$procs)
$lines+=('Programas de inicio. '+$startup)
$lines+=('C: libre............ '+[math]::Round($c.FreeSpace/1GB,1)+' GB ('+$freePct+'%)')
$lines+=('TRIM................ '+$(if($trimOk){'ACTIVO'}else{'REVISAR'}))
$lines+=('Internet............ '+$net+$(if($ping -ne $null){' | '+$ping+' ms'}else{''}))
$lines+=''
$lines+='LO IMPORTANTE'
if($ramPct -ge 85){$lines+='[REVISAR] La RAM esta muy ocupada ahora.'}elseif($ramPct -ge 70){$lines+='[INFO] Uso de RAM moderado/alto en esta medicion.'}else{$lines+='[OK] Uso de RAM normal en esta medicion.'}
if($freePct -lt 15){$lines+='[REVISAR] C: tiene poco espacio libre.'}elseif($freePct -lt 20){$lines+='[INFO] C: esta relativamente lleno.'}else{$lines+='[OK] Espacio libre de C: razonable.'}
if($startup -gt 12){$lines+='[REVISAR] Hay bastantes programas configurados para iniciar con Windows.'}else{$lines+='[OK] Inicio sin alerta por cantidad.'}
if(-not $trimOk){$lines+='[REVISAR] No se pudo confirmar TRIM activo.'}
if($net -eq 'OK'){$lines+='[OK] Conectividad basica disponible.'}else{$lines+='[INFO] No se pudo confirmar Internet durante esta prueba.'}
$lines+=''
$lines+='Este analisis no modifica nada. Los datos tecnicos extensos se dejan para los reportes avanzados.'
$lines|ForEach-Object{Write-Host $_}
$lines|Set-Content -LiteralPath $OutFile -Encoding UTF8
exit 0
