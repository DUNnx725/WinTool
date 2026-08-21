param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Analyze','Apply')]
    [string]$Mode,
    [Parameter(Mandatory=$true)][string]$ConfigDir,
    [string]$OutFile=''
)
$ErrorActionPreference='SilentlyContinue'
if(-not(Test-Path $ConfigDir)){New-Item -ItemType Directory -Path $ConfigDir -Force|Out-Null}
$stateFile=Join-Path $ConfigDir 'MaintenanceV54.json'

function DirBytes([string]$Path,[datetime]$Older){
    if(-not(Test-Path $Path)){return [int64]0}
    $s=[int64]0
    Get-ChildItem $Path -File -Recurse -Force -ErrorAction SilentlyContinue |
      Where-Object {$_.LastWriteTime -lt $Older} |
      ForEach-Object {$s+=[int64]$_.Length}
    $s
}
function Fmt([int64]$b){
    if($b -ge 1GB){return ('{0:N2} GB' -f ($b/1GB))}
    if($b -ge 1MB){return ('{0:N1} MB' -f ($b/1MB))}
    return ('{0:N0} KB' -f ($b/1KB))
}
function CleanOld([string]$Path,[int]$Days){
    if(-not(Test-Path $Path)){return [int64]0}
    $cut=(Get-Date).AddDays(-$Days);$f=[int64]0
    Get-ChildItem $Path -File -Recurse -Force -ErrorAction SilentlyContinue |
      Where-Object {$_.LastWriteTime -lt $cut} |
      ForEach-Object{
        $l=[int64]$_.Length
        try{Remove-Item $_.FullName -Force -ErrorAction Stop;$f+=$l}catch{}
      }
    $f
}
function LastComponentCleanup {
    if(-not(Test-Path $stateFile)){return $null}
    try{([datetime](Get-Content $stateFile -Raw|ConvertFrom-Json).LastComponentCleanup)}catch{return $null}
}
function SaveState([datetime]$CompDate){
    [pscustomobject]@{LastRun=(Get-Date).ToString('s');LastComponentCleanup=$(if($CompDate){$CompDate.ToString('s')}else{$null})} |
      ConvertTo-Json|Set-Content $stateFile -Encoding UTF8
}

$cut7=(Get-Date).AddDays(-7)
$cut14=(Get-Date).AddDays(-14)
$temp=(DirBytes $env:TEMP $cut7)+(DirBytes "$env:WINDIR\Temp" $cut7)
$reports=(DirBytes "$env:ProgramData\Microsoft\Windows\WER\ReportArchive" $cut14)+(DirBytes "$env:ProgramData\Microsoft\Windows\WER\ReportQueue" $cut14)+(DirBytes "$env:LOCALAPPDATA\CrashDumps" $cut14)
$c=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$freeGB=[math]::Round($c.FreeSpace/1GB,1)
$freePct=if($c.Size){[math]::Round(($c.FreeSpace/$c.Size)*100,1)}else{0}
$last=LastComponentCleanup
$needsComp=(!$last -or ((Get-Date)-$last).TotalDays -ge 30)
$pending=$false
foreach($p in @(
 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
)){if(Test-Path $p){$pending=$true}}

if($Mode -eq 'Analyze'){
    $lines=@(
      'MANTENIMIENTO RECOMENDADO - PLAN'
      ''
      ('Temporales antiguos.......... '+(Fmt $temp))
      ('Reportes/Crash antiguos...... '+(Fmt $reports))
      ('Espacio libre C:............. '+$freeGB+' GB ('+$freePct+'%)')
      ('Optimizar unidad.............. SI - Windows decide TRIM/optimizacion')
      ('Componentes Windows.......... '+$(if($needsComp){'RECOMENDADO (no realizado en 30 dias o sin historial)'}else{'NO NECESARIO TODAVIA'}))
      ('Reinicio pendiente............ '+$(if($pending){'SI'}else{'NO'}))
      ''
      'AL APLICAR:'
      '- limpia solo TEMP/errores antiguos;'
      '- optimiza C: con la herramienta oficial;'
      '- limpia componentes Windows como maximo cada 30 dias;'
      '- NO borra caches de shaders, Papelera, Descargas ni archivos personales.'
    )
    $lines|ForEach-Object{Write-Host $_}
    if($OutFile){$lines|Set-Content $OutFile -Encoding UTF8}
    exit 0
}

$freed=[int64]0
$freed+=CleanOld $env:TEMP 7
$freed+=CleanOld "$env:WINDIR\Temp" 7
$freed+=CleanOld "$env:ProgramData\Microsoft\Windows\WER\ReportArchive" 14
$freed+=CleanOld "$env:ProgramData\Microsoft\Windows\WER\ReportQueue" 14
$freed+=CleanOld "$env:LOCALAPPDATA\CrashDumps" 14

Write-Host ('[OK] Temporales antiguos procesados: '+(Fmt $freed))
Write-Host 'Optimizando C: con defrag /O...'
& defrag.exe C: /O /U
$defragRc=$LASTEXITCODE

$compDate=$last
if($needsComp){
    Write-Host 'Limpieza periodica de componentes Windows...'
    & DISM.exe /Online /Cleanup-Image /StartComponentCleanup
    if($LASTEXITCODE -eq 0){$compDate=Get-Date}
}else{
    Write-Host '[OK] Limpieza de componentes omitida: se realizo recientemente.'
}
SaveState $compDate
Write-Host ''
Write-Host '[OK] Mantenimiento recomendado finalizado.'
if($pending){Write-Host '[INFO] Windows tiene un reinicio pendiente.'}
exit $(if($defragRc -eq 0){0}else{$defragRc})
