param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Before','After','Show')]
    [string]$Mode,
    [Parameter(Mandatory=$true)][string]$DataFile,
    [string]$OutFile=''
)
$ErrorActionPreference='SilentlyContinue'
function Snap {
    $os=Get-CimInstance Win32_OperatingSystem
    $cs=Get-CimInstance Win32_ComputerSystem
    $c=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $ramUsed=[math]::Round(($cs.TotalPhysicalMemory-($os.FreePhysicalMemory*1KB))/1GB,2)
    $samples=@()
    try{
        $samples=(Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 5).CounterSamples.CookedValue
    }catch{}
    $cpu=if($samples){[math]::Round(($samples|Measure-Object -Average).Average,1)}else{$null}
    [pscustomobject]@{
      Date=(Get-Date).ToString('s')
      Processes=@(Get-Process).Count
      Services=@(Get-Service|Where-Object Status -eq Running).Count
      Startup=@(Get-CimInstance Win32_StartupCommand).Count
      RamUsedGB=$ramUsed
      FreeCGB=[math]::Round($c.FreeSpace/1GB,2)
      CpuIdleSample=$cpu
    }
}
function EnsureParent($p){$d=Split-Path -Parent $p;if($d -and -not(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null}}
EnsureParent $DataFile

if($Mode -eq 'Before'){
    $s=Snap
    [pscustomobject]@{Before=$s;After=$null}|ConvertTo-Json -Depth 5|Set-Content $DataFile -Encoding UTF8
    Write-Host '[OK] Medicion ANTES guardada.'
    Write-Host ('Procesos: '+$s.Processes+' | RAM usada: '+$s.RamUsedGB+' GB | C: libre: '+$s.FreeCGB+' GB')
    exit 0
}
if(-not(Test-Path $DataFile)){Write-Host '[INFO] Primero crea una medicion ANTES.';exit 2}
try{$d=Get-Content $DataFile -Raw|ConvertFrom-Json}catch{Write-Host '[ERROR] Medicion anterior ilegible.';exit 2}
if($Mode -eq 'After'){
    $d.After=Snap
    $d|ConvertTo-Json -Depth 5|Set-Content $DataFile -Encoding UTF8
}
if(-not $d.After){Write-Host '[INFO] Todavia no existe medicion DESPUES.';exit 0}

$b=$d.Before;$a=$d.After
$lines=@(
 'ANTES VS DESPUES'
 ''
 ('Procesos........... {0} -> {1} ({2:+#;-#;0})' -f $b.Processes,$a.Processes,([int]$a.Processes-[int]$b.Processes))
 ('Servicios.......... {0} -> {1} ({2:+#;-#;0})' -f $b.Services,$a.Services,([int]$a.Services-[int]$b.Services))
 ('Inicio............. {0} -> {1} ({2:+#;-#;0})' -f $b.Startup,$a.Startup,([int]$a.Startup-[int]$b.Startup))
 ('RAM usada.......... {0} -> {1} GB ({2:+0.00;-0.00;0.00})' -f $b.RamUsedGB,$a.RamUsedGB,([double]$a.RamUsedGB-[double]$b.RamUsedGB))
 ('Espacio libre C:... {0} -> {1} GB ({2:+0.00;-0.00;0.00})' -f $b.FreeCGB,$a.FreeCGB,([double]$a.FreeCGB-[double]$b.FreeCGB))
 ''
 'INTERPRETACION'
 'Compara con los mismos programas abiertos y condiciones parecidas.'
 'Menos procesos o RAM no significa automaticamente mas FPS; esta vista solo muestra cambios medibles.'
)
$lines|ForEach-Object{Write-Host $_}
if($OutFile){$lines|Set-Content $OutFile -Encoding UTF8}
exit 0
