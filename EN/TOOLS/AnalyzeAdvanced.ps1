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
Write-Host 'ADVANCED ANALYSIS'
Write-Host ''
Write-Host '[1/4] Windows integrity (DISM)...'
$dism=RunCapture 'DISM ScanHealth' { DISM.exe /Online /Cleanup-Image /ScanHealth }
Write-Host '[2/4] Protected system files (SFC)...'
$sfc=RunCapture 'SFC verifyonly' { sfc.exe /verifyonly }
Write-Host '[3/4] C: file system (CHKDSK)...'
$chk=RunCapture 'CHKDSK C: /scan' { chkdsk.exe C: /scan }
Write-Host '[4/4] Checking important events...'

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

    D('');D('===== IMPORTANT EVENTS =====')
    foreach($e in $important){
        D(('{0} | {1} | ID {2} | {3}' -f $e.TimeCreated,$e.ProviderName,$e.Id,$e.LevelDisplayName))
        D([string]$e.Message);D('')
    }
    D('');D('===== INFORMATIONAL WHEA EVENTS (NOT CLASSIFIED AS ERRORS) =====')
    foreach($e in $wheaInfo){
        D(('{0} | ID {1} | {2}' -f $e.TimeCreated,$e.Id,$e.LevelDisplayName))
        D([string]$e.Message);D('')
    }
}catch{D('[INFO] Not all events could be read.')}

D('');D('End: '+(Get-Date))
[IO.File]::WriteAllLines($OutFile,$detail,(New-Object Text.UTF8Encoding($false)))

Write-Host ''
Write-Host 'SIMPLE RESULT'
Write-Host ('DISM.................. '+$(if($dism -eq 0){'COMPLETED'}else{'CHECK REPORT'}))
Write-Host ('SFC................... '+$(if($sfc -eq 0){'COMPLETED'}else{'CHECK REPORT'}))
Write-Host ('CHKDSK................ '+$(if($chk -eq 0){'COMPLETED'}else{'CHECK REPORT'}))
Write-Host ('Important alerts... '+$important.Count)
Write-Host ('Informational WHEA events..... '+$wheaInfo.Count)
if($important.Count -eq 0){
    Write-Host '[OK] No important warnings/errors were found in the 7-day sample.'
}else{
    Write-Host '[CHECK] Warning/error events were found. The report contains details.'
}
if($wheaInfo.Count -gt 0){
    Write-Host '[INFO] Information-level WHEA events are shown separately and do not count as failures.'
}
Write-Host ('Technical report: '+$OutFile)
exit 0
