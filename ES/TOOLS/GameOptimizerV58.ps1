param(
 [ValidateSet('Inspect','Apply','Restore')][string]$Mode='Inspect',
 [Parameter(Mandatory=$true)][int]$TargetPid,
 [Parameter(Mandatory=$true)][string]$StateDir
)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
$stateFile=Join-Path $StateDir ("GameOptimizer_{0}.json" -f $TargetPid)

function PriorityRank([string]$n){
 switch($n){
  'Idle'{0};'BelowNormal'{1};'Normal'{2};'AboveNormal'{3};'High'{4};'RealTime'{5};default{-1}
 }
}
function GetTarget {
 try { Get-Process -Id $TargetPid -ErrorAction Stop } catch { $null }
}
function ShowState($p){
 Write-Host ('Proceso................ '+$p.ProcessName+'.exe')
 Write-Host ('PID.................... '+$p.Id)
 Write-Host ('Prioridad actual....... '+$p.PriorityClass)
 if((PriorityRank ([string]$p.PriorityClass)) -ge (PriorityRank 'AboveNormal')){
   Write-Host '[OK] WinTool no bajara ni reemplazara esta prioridad.'
 } else {
   Write-Host '[INFO] WinTool puede elevarla temporalmente a ABOVE NORMAL.'
 }
 Write-Host '[OK] Afinidad de CPU: NO SE TOCA.'
 Write-Host '[OK] Prioridad REALTIME: NUNCA SE APLICA.'
 Write-Host '[OK] Cambios: solo temporales y restaurables.'
}
$p=GetTarget
if(-not $p){Write-Host '[REVISAR] El juego ya no esta ejecutandose.';exit 3}

if($Mode -eq 'Inspect'){ ShowState $p; exit 0 }

if($Mode -eq 'Apply'){
 $current=[string]$p.PriorityClass
 $state=[ordered]@{
   Version='5.8.0'; PID=$p.Id; Process=$p.ProcessName
   OriginalPriority=$current; ChangedPriority=$false
   AppliedAt=(Get-Date).ToString('o')
 }
 if((PriorityRank $current) -lt (PriorityRank 'AboveNormal')){
   try{
     $p.PriorityClass='AboveNormal'
     $state.ChangedPriority=$true
     Write-Host ('[OK] Prioridad: '+$current+' -> AboveNormal')
   }catch{
     Write-Host '[REVISAR] Windows no permitio cambiar la prioridad del proceso.'
   }
 } else {
   Write-Host ('[OK] Prioridad existente conservada: '+$current)
 }
 $state | ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding UTF8
 Write-Host '[OK] No se modifico afinidad, GPU Priority, HPET, BCD ni prioridad REALTIME.'
 exit 0
}

if($Mode -eq 'Restore'){
 if(-not(Test-Path -LiteralPath $stateFile)){
   Write-Host '[INFO] WinTool no tiene cambios temporales registrados para este proceso.'
   exit 0
 }
 try{$s=Get-Content -LiteralPath $stateFile -Raw|ConvertFrom-Json}catch{
   Write-Host '[REVISAR] El registro temporal no se pudo leer.';exit 4
 }
 if($s.ChangedPriority){
   try{
     $p.PriorityClass=[System.Diagnostics.ProcessPriorityClass]::$($s.OriginalPriority)
     Write-Host ('[OK] Prioridad restaurada a '+$s.OriginalPriority)
   }catch{
     Write-Host '[REVISAR] No se pudo restaurar la prioridad. El proceso puede haber cambiado o cerrado.'
     exit 5
   }
 }else{
   Write-Host '[OK] WinTool no habia cambiado la prioridad.'
 }
 Remove-Item -LiteralPath $stateFile -Force -ErrorAction SilentlyContinue
 exit 0
}
