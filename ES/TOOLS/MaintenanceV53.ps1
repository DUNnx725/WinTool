param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Analyze','SafeClean','RegenerableCaches','RecycleBin','ComponentCleanup','OptimizeC','ShadowInfo')]
    [string]$Mode,
    [string]$OutFile=''
)
$ErrorActionPreference='SilentlyContinue'

function Get-DirBytes([string]$Path,[datetime]$OlderThan=[datetime]::MinValue){
    if(-not (Test-Path -LiteralPath $Path)){ return [int64]0 }
    $sum=[int64]0
    Get-ChildItem -LiteralPath $Path -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object {$_.LastWriteTime -lt $OlderThan} |
        ForEach-Object {$sum += [int64]$_.Length}
    return $sum
}
function Fmt([int64]$Bytes){
    if($Bytes -ge 1GB){return ('{0:N2} GB' -f ($Bytes/1GB))}
    if($Bytes -ge 1MB){return ('{0:N1} MB' -f ($Bytes/1MB))}
    if($Bytes -ge 1KB){return ('{0:N1} KB' -f ($Bytes/1KB))}
    return "$Bytes B"
}
function Remove-Old([string]$Path,[int]$Days){
    if(-not (Test-Path -LiteralPath $Path)){return [int64]0}
    $cut=(Get-Date).AddDays(-$Days)
    $freed=[int64]0
    Get-ChildItem -LiteralPath $Path -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object {$_.LastWriteTime -lt $cut} |
        ForEach-Object {
            $len=[int64]$_.Length
            try{Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop;$freed+=$len}catch{}
        }
    Get-ChildItem -LiteralPath $Path -Directory -Recurse -Force -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        ForEach-Object {
            try{
                if(-not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction Stop)){
                    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                }
            }catch{}
        }
    return $freed
}
function WriteReport($Lines){
    $Lines|ForEach-Object{Write-Host $_}
    if($OutFile){$Lines|Set-Content -LiteralPath $OutFile -Encoding UTF8}
}

if($Mode -eq 'Analyze'){
    $cut7=(Get-Date).AddDays(-7)
    $cut14=(Get-Date).AddDays(-14)
    $userTemp=Get-DirBytes $env:TEMP $cut7
    $winTemp=Get-DirBytes "$env:WINDIR\Temp" $cut7
    $wer1=Get-DirBytes "$env:ProgramData\Microsoft\Windows\WER\ReportArchive" $cut14
    $wer2=Get-DirBytes "$env:ProgramData\Microsoft\Windows\WER\ReportQueue" $cut14
    $crash=Get-DirBytes "$env:LOCALAPPDATA\CrashDumps" $cut14
    $d3d=Get-DirBytes "$env:LOCALAPPDATA\D3DSCache"
    $thumb=Get-DirBytes "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
    $tmpApps=Get-DirBytes "$env:ProgramFiles\WindowsApps.tmp"
    $c=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $freePct=if($c.Size){[math]::Round(($c.FreeSpace/$c.Size)*100,1)}else{0}
    $trim=(fsutil behavior query DisableDeleteNotify 2>$null|Out-String)
    $trimState=if($trim -match 'DisableDeleteNotify\s*=\s*0'){'ACTIVO'}else{'REVISAR'}
    $startup=@(Get-CimInstance Win32_StartupCommand).Count
    $lines=@()
    $lines+='MANTENIMIENTO INTELIGENTE'
    $lines+=('Fecha: '+(Get-Date))
    $lines+=''
    $lines+='LIMPIEZA SEGURA DETECTADA'
    $lines+=('TEMP usuario (>7 dias)........ '+(Fmt $userTemp))
    $lines+=('Windows Temp (>7 dias)........ '+(Fmt $winTemp))
    $lines+=('WER antiguo (>14 dias)........ '+(Fmt ($wer1+$wer2)))
    $lines+=('CrashDumps antiguos............ '+(Fmt $crash))
    $lines+=('Total seguro estimado.......... '+(Fmt ($userTemp+$winTemp+$wer1+$wer2+$crash)))
    $lines+=''
    $lines+='CACHES REGENERABLES - OPCIONALES'
    $lines+=('DirectX Shader Cache............ '+(Fmt $d3d))
    $lines+=('Explorer / miniaturas.......... '+(Fmt $thumb))
    $lines+='Delivery Optimization........... usar opcion dedicada para vaciarla'
    $lines+=''
    $lines+='ESTADO'
    $lines+=('Espacio libre C:................ {0:N1} GB ({1}%)' -f ($c.FreeSpace/1GB),$freePct)
    $lines+=('TRIM............................ '+$trimState)
    $lines+=('Entradas de inicio.............. '+$startup)
    $lines+=('WindowsApps.tmp................. '+(Fmt $tmpApps)+' [SOLO INFORMACION]')
    $lines+=''
    $lines+='RECOMENDACIONES'
    if(($userTemp+$winTemp+$wer1+$wer2+$crash) -ge 500MB){$lines+='[RECOMENDADO] Hay al menos 500 MB de archivos antiguos seguros para procesar.'}
    else{$lines+='[OK] La limpieza segura no tiene mucho que recuperar.'}
    if($freePct -lt 15){$lines+='[REVISAR] C: tiene menos de 15% libre.'}
    elseif($freePct -lt 20){$lines+='[INFO] C: esta relativamente lleno; conviene recuperar algo de espacio.'}
    else{$lines+='[OK] Espacio libre de C: razonable.'}
    if($tmpApps -ge 1GB){$lines+='[REVISAR] WindowsApps.tmp es grande. WinTool NO lo elimina automaticamente.'}
    if($d3d -ge 500MB){$lines+='[OPCIONAL] Shader cache grande. Borrarla puede causar recompilacion/stutter temporal.'}
    if($startup -gt 12){$lines+='[REVISAR] Muchas entradas de inicio; conviene revisarlas.'}
    $lines+='[OK] Minecraft, Descargas, documentos, pagefile, WinSxS y WindowsApps quedan excluidos.'
    WriteReport $lines
    exit 0
}

if($Mode -eq 'SafeClean'){
    Write-Host 'LIMPIEZA SEGURA'
    Write-Host 'Procesando solo archivos antiguos en ubicaciones temporales/reportes...'
    $freed=[int64]0
    $freed+=Remove-Old $env:TEMP 7
    $freed+=Remove-Old "$env:WINDIR\Temp" 7
    $freed+=Remove-Old "$env:ProgramData\Microsoft\Windows\WER\ReportArchive" 14
    $freed+=Remove-Old "$env:ProgramData\Microsoft\Windows\WER\ReportQueue" 14
    $freed+=Remove-Old "$env:LOCALAPPDATA\CrashDumps" 14
    Write-Host ('[OK] Liberado aproximadamente: '+(Fmt $freed))
    Write-Host 'No se tocaron Descargas, Minecraft, WindowsApps, WinSxS ni archivos personales.'
    exit 0
}

if($Mode -eq 'RegenerableCaches'){
    $before=[int64]0
    $before+=Get-DirBytes "$env:LOCALAPPDATA\D3DSCache"
    $before+=Get-DirBytes "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
    Write-Host 'CACHES REGENERABLES'
    Write-Host 'Eliminando cache DirectX y cache de miniaturas.'
    Write-Host 'Los juegos pueden recompilar shaders y presentar stutter temporal despues de esto.'
    try{Remove-Item "$env:LOCALAPPDATA\D3DSCache\*" -Recurse -Force -ErrorAction SilentlyContinue}catch{}
    try{
        Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Filter 'thumbcache_*.db' -Force |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }catch{}
    if(Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue){
        try{
            Delete-DeliveryOptimizationCache -Force -ErrorAction Stop
            Write-Host '[OK] Cache de Delivery Optimization procesada.'
        }catch{Write-Host '[INFO] Delivery Optimization no pudo vaciarse en este momento.'}
    }else{
        Write-Host '[INFO] Cmdlet de Delivery Optimization no disponible en esta instalacion.'
    }
    Write-Host ('Caches locales detectadas antes: '+(Fmt $before))
    exit 0
}

if($Mode -eq 'RecycleBin'){
    try{
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Host '[OK] Papelera vaciada.'
        exit 0
    }catch{
        Write-Host '[INFO] Papelera vacia o no se pudo procesar algun volumen.'
        exit 0
    }
}

if($Mode -eq 'ComponentCleanup'){
    Write-Host 'DISM /StartComponentCleanup'
    Write-Host 'Limpia componentes reemplazados mediante la herramienta oficial de Windows.'
    & DISM.exe /Online /Cleanup-Image /StartComponentCleanup
    exit $LASTEXITCODE
}

if($Mode -eq 'OptimizeC'){
    Write-Host 'OPTIMIZAR C:'
    Write-Host 'Windows elegira la operacion adecuada para el tipo de unidad con defrag /O.'
    & defrag.exe C: /O /U /V
    exit $LASTEXITCODE
}

if($Mode -eq 'ShadowInfo'){
    Write-Host 'PUNTOS DE RESTAURACION / VSS'
    & vssadmin.exe list shadowstorage
    Write-Host ''
    Write-Host 'WINDOWSAPPS.TMP'
    $p="$env:ProgramFiles\WindowsApps.tmp"
    if(Test-Path $p){
        $b=Get-DirBytes $p
        Write-Host ('Tamano detectado: '+(Fmt $b))
        Write-Host 'WinTool NO elimina esta carpeta automaticamente.'
    }else{Write-Host 'No se encontro WindowsApps.tmp.'}
    exit 0
}
