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
 Write-Host ('Process................ '+$p.ProcessName+'.exe')
 Write-Host ('PID.................... '+$p.Id)
 Write-Host ('Current priority....... '+$p.PriorityClass)
 if((PriorityRank ([string]$p.PriorityClass)) -ge (PriorityRank 'AboveNormal')){
   Write-Host '[OK] WinTool will not lower or replace this priority.'
 } else {
   Write-Host '[INFO] WinTool can temporarily raise it to ABOVE NORMAL.'
 }
 Write-Host '[OK] CPU affinity: NOT CHANGED.'
 Write-Host '[OK] REALTIME priority: NEVER APPLIED.'
 Write-Host '[OK] Changes are temporary and restorable only.'
}
$p=GetTarget
if(-not $p){Write-Host '[CHECK] The game is no longer running.';exit 3}

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
     Write-Host ('[OK] Priority: '+$current+' -> AboveNormal')
   }catch{
     Write-Host '[CHECK] Windows did not allow the process priority to be changed.'
   }
 } else {
   Write-Host ('[OK] Existing priority preserved: '+$current)
 }
 $state | ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding UTF8
 Write-Host '[OK] Affinity, GPU Priority, HPET, BCD and REALTIME priority were not changed.'
 exit 0
}

if($Mode -eq 'Restore'){
 if(-not(Test-Path -LiteralPath $stateFile)){
   Write-Host '[INFO] WinTool has no temporary changes recorded for this process.'
   exit 0
 }
 try{$s=Get-Content -LiteralPath $stateFile -Raw|ConvertFrom-Json}catch{
   Write-Host '[CHECK] The temporary record could not be read.';exit 4
 }
 if($s.ChangedPriority){
   try{
     $p.PriorityClass=[System.Diagnostics.ProcessPriorityClass]::$($s.OriginalPriority)
     Write-Host ('[OK] Priority restored to '+$s.OriginalPriority)
   }catch{
     Write-Host '[CHECK] Priority could not be restored. The process may have changed or closed.'
     exit 5
   }
 }else{
   Write-Host '[OK] WinTool had not changed the priority.'
 }
 Remove-Item -LiteralPath $stateFile -Force -ErrorAction SilentlyContinue
 exit 0
}
