param(
    [string]$OutFile='',
    [int]$Days=7
)
$ErrorActionPreference='SilentlyContinue'
$since=(Get-Date).AddDays(-[math]::Max(1,$Days))
$alerts=New-Object System.Collections.Generic.List[string]
$infos=New-Object System.Collections.Generic.List[string]
$details=New-Object System.Collections.Generic.List[string]

function AddAlert([string]$Text){$alerts.Add($Text)}
function AddInfo([string]$Text){$infos.Add($Text)}
function AddDetail([string]$Text){$details.Add($Text)}

# Storage / free space
$c=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
if($c -and $c.Size){
    $freePct=[math]::Round(($c.FreeSpace/$c.Size)*100,1)
    $freeGB=[math]::Round($c.FreeSpace/1GB,1)
    if($freePct -lt 10){AddAlert "Drive C: is very full: $freeGB GB free ($freePct%)."}
    elseif($freePct -lt 15){AddAlert "Low free space on C: $freeGB GB ($freePct%)."}
    elseif($freePct -lt 20){AddInfo "C: is relatively full: $freeGB GB free ($freePct%)."}
    else{AddInfo "Free space on C: is healthy: $freeGB GB."}
}

# Pending reboot
$pending=$false
foreach($p in @(
 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
)){if(Test-Path $p){$pending=$true}}
if($pending){AddInfo 'Windows has a pending restart.'}

# WHEA: distinguish informational from warning/error/critical.
$whea=@()
try{
    $whea=@(Get-WinEvent -FilterHashtable @{
        LogName='System'
        ProviderName='Microsoft-Windows-WHEA-Logger'
        StartTime=$since
    } -ErrorAction Stop)
}catch{}

$wheaBad=@($whea|Where-Object {$_.Level -in 1,2,3})
$wheaInfo=@($whea|Where-Object {$_.Level -eq 4 -or $_.LevelDisplayName -match 'Information|Informacion|Información'})

if($wheaBad.Count -gt 0){
    $last=$wheaBad|Sort-Object TimeCreated -Descending|Select-Object -First 1
    AddAlert ("WHEA: {0} hardware warning(s)/error(s) in {1} days. Latest: {2:dd/MM HH:mm}, ID {3}." -f $wheaBad.Count,$Days,$last.TimeCreated,$last.Id)
}else{
    if($wheaInfo.Count -gt 0){
        $last=$wheaInfo|Sort-Object TimeCreated -Descending|Select-Object -First 1
        AddInfo ("WHEA: only {0} informational event(s). Latest: {1:dd/MM HH:mm}, ID {2}. It is not classified as a failure." -f $wheaInfo.Count,$last.TimeCreated,$last.Id)
    }else{
        AddInfo "WHEA: no recent events."
    }
}

foreach($e in ($whea|Sort-Object TimeCreated -Descending|Select-Object -First 20)){
    AddDetail ("WHEA | {0:yyyy-MM-dd HH:mm:ss} | Nivel {1} | ID {2} | {3}" -f $e.TimeCreated,$e.LevelDisplayName,$e.Id,([string]$e.Message).Replace("`r"," ").Replace("`n"," "))
}

# Disk / NTFS / NVMe errors: only warning/error/critical.
$diskEvents=@()
try{
    $diskEvents=@(Get-WinEvent -FilterHashtable @{LogName='System';StartTime=$since} -MaxEvents 1000 |
        Where-Object {
            $_.Level -in 1,2,3 -and
            $_.ProviderName -match '^(Disk|Ntfs|Microsoft-Windows-StorNVMe|stornvme)$'
        })
}catch{}
if($diskEvents.Count -gt 0){
    $last=$diskEvents|Sort-Object TimeCreated -Descending|Select-Object -First 1
    AddAlert ("Storage: {0} warning/error event(s). Latest: {1:dd/MM HH:mm}, {2}, ID {3}." -f $diskEvents.Count,$last.TimeCreated,$last.ProviderName,$last.Id)
}else{
    AddInfo 'Storage: no recent Disk/NTFS/NVMe warnings or errors.'
}
foreach($e in ($diskEvents|Sort-Object TimeCreated -Descending|Select-Object -First 20)){
    AddDetail ("STORAGE | {0:yyyy-MM-dd HH:mm:ss} | {1} | ID {2} | {3}" -f $e.TimeCreated,$e.ProviderName,$e.Id,([string]$e.Message).Replace("`r"," ").Replace("`n"," "))
}

# Unexpected shutdown / Kernel-Power 41
$kp=@()
try{
    $kp=@(Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-Kernel-Power';Id=41;StartTime=$since})
}catch{}
if($kp.Count -gt 0){
    $last=$kp|Sort-Object TimeCreated -Descending|Select-Object -First 1
    AddInfo ("Unexpected shutdowns/restarts: {0} in {1} days. Latest: {2:dd/MM HH:mm}." -f $kp.Count,$Days,$last.TimeCreated)
}

# Display driver errors/warnings
$display=@()
try{
    $display=@(Get-WinEvent -FilterHashtable @{LogName='System';StartTime=$since} -MaxEvents 1000 |
      Where-Object {$_.Level -in 1,2,3 -and $_.ProviderName -match 'Display|amdwddmg|nvlddmkm'})
}catch{}
if($display.Count -gt 0){
    $last=$display|Sort-Object TimeCreated -Descending|Select-Object -First 1
    AddAlert ("Graphics: {0} recent warning(s)/error(s). Latest: {1:dd/MM HH:mm}, ID {2}." -f $display.Count,$last.TimeCreated,$last.Id)
}

# Startup count
$startup=@(Get-CimInstance Win32_StartupCommand).Count
if($startup -gt 15){AddInfo "Startup: $startup entries. Consider reviewing which ones you actually need."}
elseif($startup -gt 10){AddInfo "Startup: $startup entries. Moderate count."}
else{AddInfo "Startup: $startup entries. No alert based on count."}

# Output friendly summary
$lines=New-Object System.Collections.Generic.List[string]
$lines.Add('SMART ALERTS')
$lines.Add(('Period checked: last {0} days' -f $Days))
$lines.Add('')
if($alerts.Count -eq 0){
    $lines.Add('[OK] No important alerts were detected.')
}else{
    $lines.Add(('{0} ALERT(S) FOUND:' -f $alerts.Count))
    foreach($a in $alerts){$lines.Add('[CHECK] '+$a)}
}
$lines.Add('')
$lines.Add('USEFUL INFORMATION')
foreach($i in $infos){$lines.Add('[INFO] '+$i)}
$lines.Add('')
$lines.Add('HOW TO READ THIS')
$lines.Add('- INFO: useful information; it does not imply a failure.')
$lines.Add('- CHECK: worth checking, but it does not automatically mean faulty hardware.')
$lines.Add('- Information-level WHEA events are no longer classified as errors.')
$lines.Add('')

$lines|ForEach-Object{Write-Host $_}

if($OutFile){
    $all=New-Object System.Collections.Generic.List[string]
    foreach($x in $lines){$all.Add($x)}
    $all.Add('TECHNICAL DETAILS')
    $all.Add('----------------')
    foreach($x in $details){$all.Add($x)}
    [IO.File]::WriteAllLines($OutFile,$all,(New-Object Text.UTF8Encoding($false)))
}
exit 0
