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
    $trimState=if($trim -match 'DisableDeleteNotify\s*=\s*0'){'ACTIVE'}else{'CHECK'}
    $startup=@(Get-CimInstance Win32_StartupCommand).Count
    $lines=@()
    $lines+='SMART MAINTENANCE'
    $lines+=('Date: '+(Get-Date))
    $lines+=''
    $lines+='SAFE CLEANUP DETECTED'
    $lines+=('User TEMP (>7 days)........ '+(Fmt $userTemp))
    $lines+=('Windows Temp (>7 days)........ '+(Fmt $winTemp))
    $lines+=('Old WER (>14 days)........ '+(Fmt ($wer1+$wer2)))
    $lines+=('Old CrashDumps............ '+(Fmt $crash))
    $lines+=('Estimated safe total.......... '+(Fmt ($userTemp+$winTemp+$wer1+$wer2+$crash)))
    $lines+=''
    $lines+='REGENERABLE CACHES - OPTIONAL'
    $lines+=('DirectX Shader Cache............ '+(Fmt $d3d))
    $lines+=('Explorer / thumbnails.......... '+(Fmt $thumb))
    $lines+='Delivery Optimization........... use the dedicated option to clear it'
    $lines+=''
    $lines+='STATUS'
    $lines+=('Free space on C:................ {0:N1} GB ({1}%)' -f ($c.FreeSpace/1GB),$freePct)
    $lines+=('TRIM............................ '+$trimState)
    $lines+=('Startup entries.............. '+$startup)
    $lines+=('WindowsApps.tmp................. '+(Fmt $tmpApps)+' [INFORMATION ONLY]')
    $lines+=''
    $lines+='RECOMMENDATIONS'
    if(($userTemp+$winTemp+$wer1+$wer2+$crash) -ge 500MB){$lines+='[RECOMMENDED] At least 500 MB of old safe-to-process files were found.'}
    else{$lines+='[OK] Safe cleanup has little space to recover.'}
    if($freePct -lt 15){$lines+='[CHECK] C: has less than 15% free space.'}
    elseif($freePct -lt 20){$lines+='[INFO] C: is relatively full; freeing some space is recommended.'}
    else{$lines+='[OK] C: has a reasonable amount of free space.'}
    if($tmpApps -ge 1GB){$lines+='[CHECK] WindowsApps.tmp is large. WinTool does NOT delete it automatically.'}
    if($d3d -ge 500MB){$lines+='[OPTIONAL] Large shader cache. Clearing it may cause temporary recompilation/stutter.'}
    if($startup -gt 12){$lines+='[CHECK] Many startup entries were found; reviewing them is recommended.'}
    $lines+='[OK] Minecraft, Downloads, documents, pagefile, WinSxS and WindowsApps are excluded.'
    WriteReport $lines
    exit 0
}

if($Mode -eq 'SafeClean'){
    Write-Host 'SAFE CLEANUP'
    Write-Host 'Processing only old files in temporary/report locations...'
    $freed=[int64]0
    $freed+=Remove-Old $env:TEMP 7
    $freed+=Remove-Old "$env:WINDIR\Temp" 7
    $freed+=Remove-Old "$env:ProgramData\Microsoft\Windows\WER\ReportArchive" 14
    $freed+=Remove-Old "$env:ProgramData\Microsoft\Windows\WER\ReportQueue" 14
    $freed+=Remove-Old "$env:LOCALAPPDATA\CrashDumps" 14
    Write-Host ('[OK] Approximately freed: '+(Fmt $freed))
    Write-Host 'Downloads, Minecraft, WindowsApps, WinSxS and personal files were not touched.'
    exit 0
}

if($Mode -eq 'RegenerableCaches'){
    $before=[int64]0
    $before+=Get-DirBytes "$env:LOCALAPPDATA\D3DSCache"
    $before+=Get-DirBytes "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
    Write-Host 'REGENERABLE CACHES'
    Write-Host 'Clearing DirectX cache and thumbnail cache.'
    Write-Host 'Games may recompile shaders and temporarily stutter after this.'
    try{Remove-Item "$env:LOCALAPPDATA\D3DSCache\*" -Recurse -Force -ErrorAction SilentlyContinue}catch{}
    try{
        Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Filter 'thumbcache_*.db' -Force |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }catch{}
    if(Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue){
        try{
            Delete-DeliveryOptimizationCache -Force -ErrorAction Stop
            Write-Host '[OK] Delivery Optimization cache processed.'
        }catch{Write-Host '[INFO] Delivery Optimization could not be cleared at this time.'}
    }else{
        Write-Host '[INFO] Delivery Optimization cmdlet is not available on this installation.'
    }
    Write-Host ('Local caches detected before: '+(Fmt $before))
    exit 0
}

if($Mode -eq 'RecycleBin'){
    try{
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Host '[OK] Recycle Bin emptied.'
        exit 0
    }catch{
        Write-Host '[INFO] Recycle Bin is empty or one volume could not be processed.'
        exit 0
    }
}

if($Mode -eq 'ComponentCleanup'){
    Write-Host 'DISM /StartComponentCleanup'
    Write-Host 'Cleans replaced components using the official Windows tool.'
    & DISM.exe /Online /Cleanup-Image /StartComponentCleanup
    exit $LASTEXITCODE
}

if($Mode -eq 'OptimizeC'){
    Write-Host 'OPTIMIZE C:'
    Write-Host 'Windows will choose the appropriate operation for the drive type with defrag /O.'
    & defrag.exe C: /O /U /V
    exit $LASTEXITCODE
}

if($Mode -eq 'ShadowInfo'){
    Write-Host 'RESTORE POINTS / VSS'
    & vssadmin.exe list shadowstorage
    Write-Host ''
    Write-Host 'WINDOWSAPPS.TMP'
    $p="$env:ProgramFiles\WindowsApps.tmp"
    if(Test-Path $p){
        $b=Get-DirBytes $p
        Write-Host ('Detected size: '+(Fmt $b))
        Write-Host 'WinTool does NOT delete this folder automatically.'
    }else{Write-Host 'WindowsApps.tmp was not found.'}
    exit 0
}
