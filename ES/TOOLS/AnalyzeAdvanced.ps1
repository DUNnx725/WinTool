param([Parameter(Mandatory=$true)][string]$OutFile)
$ErrorActionPreference='Continue'
$detail=New-Object System.Collections.Generic.List[string]
function D([string]$s=''){$detail.Add($s)}
function RunCapture([string]$Title,[scriptblock]$Cmd){
    D('');D('===== '+$Title+' =====')
    try{
        $o=& $Cmd 2>&1
        foreach($x in $o){D([string]$x)}
        return $LASTEXITCODE
    }catch{D('[ERROR] '+$_.Exception.Message);return 999}
}
Write-Host 'ANALISIS AVANZADO'
Write-Host ''
Write-Host '[1/4] Integridad de Windows (DISM)...'
$dism=RunCapture 'DISM ScanHealth' { DISM.exe /Online /Cleanup-Image /ScanHealth }
Write-Host '[2/4] Archivos protegidos (SFC)...'
$sfc=RunCapture 'SFC verifyonly' { sfc.exe /verifyonly }
Write-Host '[3/4] Sistema de archivos C: (CHKDSK)...'
$chk=RunCapture 'CHKDSK C: /scan' { chkdsk.exe C: /scan }
Write-Host '[4/4] Revisando eventos importantes...'

$since=(Get-Date).AddDays(-7)
$important=@()
$wheaInfo=@()
try{
    $all=Get-WinEvent -FilterHashtable @{LogName='System';StartTime=$since} -MaxEvents 1500
    $important=@($all|Where-Object {
        $_.Level -in 1,2,3 -and
        $_.ProviderName -match 'WHEA|Disk|Ntfs|stornvme|StorNVMe|Display|Kernel-Power'
    }|Select-Object -First 50)
    $wheaInfo=@($all|Where-Object {
        $_.ProviderName -eq 'Microsoft-Windows-WHEA-Logger' -and
        ($_.Level -eq 4 -or $_.LevelDisplayName -match 'Information|Informacion|Información')
    }|Select-Object -First 30)

    D('');D('===== EVENTOS IMPORTANTES =====')
    foreach($e in $important){
        D(('{0} | {1} | ID {2} | {3}' -f $e.TimeCreated,$e.ProviderName,$e.Id,$e.LevelDisplayName))
        D([string]$e.Message);D('')
    }
    D('');D('===== WHEA INFORMATIVOS (NO SE CLASIFICAN COMO ERROR) =====')
    foreach($e in $wheaInfo){
        D(('{0} | ID {1} | {2}' -f $e.TimeCreated,$e.Id,$e.LevelDisplayName))
        D([string]$e.Message);D('')
    }
}catch{D('[INFO] No se pudieron leer todos los eventos.')}

D('');D('Fin: '+(Get-Date))
[IO.File]::WriteAllLines($OutFile,$detail,(New-Object Text.UTF8Encoding($false)))

Write-Host ''
Write-Host 'RESULTADO SIMPLE'
Write-Host ('DISM.................. '+$(if($dism -eq 0){'COMPLETADO'}else{'REVISAR REPORTE'}))
Write-Host ('SFC................... '+$(if($sfc -eq 0){'COMPLETADO'}else{'REVISAR REPORTE'}))
Write-Host ('CHKDSK................ '+$(if($chk -eq 0){'COMPLETADO'}else{'REVISAR REPORTE'}))
Write-Host ('Alertas importantes... '+$important.Count)
Write-Host ('WHEA informativos..... '+$wheaInfo.Count)
if($important.Count -eq 0){
    Write-Host '[OK] No se encontraron advertencias/errores importantes en la muestra de 7 dias.'
}else{
    Write-Host '[REVISAR] Hay eventos de advertencia/error. El reporte contiene el detalle.'
}
if($wheaInfo.Count -gt 0){
    Write-Host '[INFO] Los WHEA de nivel Informacion se muestran aparte y no cuentan como fallo.'
}
Write-Host ('Reporte tecnico: '+$OutFile)
exit 0
