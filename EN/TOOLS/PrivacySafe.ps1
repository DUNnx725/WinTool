param([Parameter(Mandatory=$true)][string]$BackupDir,[switch]$Restore)
$ErrorActionPreference='Stop'
$bk=Join-Path $BackupDir 'PrivacySafe.json'
$items=@(
    @{P='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager';N='SubscribedContent-338389Enabled';V=0;D='Windows suggestions'},
    @{P='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager';N='SilentInstalledAppsEnabled';V=0;D='Silently suggested apps'},
    @{P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection';N='AllowTelemetry';V=1;D='Reduced telemetry'}
)
function Set-Dword([string]$Path,[string]$Name,[int]$Value){
    if(!(Test-Path $Path)){New-Item -Path $Path -Force|Out-Null}
    $prop=Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    if($null -eq $prop){New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force|Out-Null}
    else{Set-ItemProperty -Path $Path -Name $Name -Value $Value}
}
if($Restore){
    if(!(Test-Path $bk)){Write-Host '[INFO] No backup found.';exit 0}
    $data=Get-Content $bk -Raw|ConvertFrom-Json
    foreach($x in $data){
        if([bool]$x.Exists){Set-Dword $x.P $x.N ([int]$x.O)}
        else{Remove-ItemProperty -Path $x.P -Name $x.N -ErrorAction SilentlyContinue}
    }
    Write-Host '[OK] Privacy settings restored.';exit 0
}
$backup=@();$changes=0
foreach($i in $items){
    $prop=Get-ItemProperty -Path $i.P -Name $i.N -ErrorAction SilentlyContinue
    $exists=$null -ne $prop
    $old=if($exists){$prop.($i.N)}else{$null}
    $backup+=@{P=$i.P;N=$i.N;Exists=$exists;O=$old}
    $state=if($old -eq $i.V){'OK'}else{'CHECK';$changes++}
    Write-Host ("[$state] $($i.D) | current=$old | recommended=$($i.V)")
}
$backup|ConvertTo-Json -Depth 4|Set-Content $bk -Encoding UTF8
if($changes -eq 0){Write-Host '[OK] No recommended changes were found.';exit 0}
$ans=Read-Host 'Apply these settings? [Y/N]'
if($ans -notmatch '^[Yy]'){Write-Host 'No changes made.';exit 0}
foreach($i in $items){Set-Dword $i.P $i.N ([int]$i.V)}
Write-Host '[OK] Settings applied.'
exit 0
