param([Parameter(Mandatory=$true)][string]$BackupDir,[switch]$Restore)
$ErrorActionPreference='Stop'
$bk=Join-Path $BackupDir 'PrivacySafe.json'
$items=@(
    @{P='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager';N='SubscribedContent-338389Enabled';V=0;D='Sugerencias de Windows'},
    @{P='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager';N='SilentInstalledAppsEnabled';V=0;D='Apps sugeridas silenciosas'},
    @{P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection';N='AllowTelemetry';V=1;D='Telemetria reducida'}
)
function Set-Dword([string]$Path,[string]$Name,[int]$Value){
    if(!(Test-Path $Path)){New-Item -Path $Path -Force|Out-Null}
    $prop=Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    if($null -eq $prop){New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force|Out-Null}
    else{Set-ItemProperty -Path $Path -Name $Name -Value $Value}
}
if($Restore){
    if(!(Test-Path $bk)){Write-Host '[INFO] Sin backup.';exit 0}
    $data=Get-Content $bk -Raw|ConvertFrom-Json
    foreach($x in $data){
        if([bool]$x.Exists){Set-Dword $x.P $x.N ([int]$x.O)}
        else{Remove-ItemProperty -Path $x.P -Name $x.N -ErrorAction SilentlyContinue}
    }
    Write-Host '[OK] Privacidad restaurada.';exit 0
}
$backup=@();$changes=0
foreach($i in $items){
    $prop=Get-ItemProperty -Path $i.P -Name $i.N -ErrorAction SilentlyContinue
    $exists=$null -ne $prop
    $old=if($exists){$prop.($i.N)}else{$null}
    $backup+=@{P=$i.P;N=$i.N;Exists=$exists;O=$old}
    $state=if($old -eq $i.V){'OK'}else{'REVISAR';$changes++}
    Write-Host ("[$state] $($i.D) | actual=$old | recomendado=$($i.V)")
}
$backup|ConvertTo-Json -Depth 4|Set-Content $bk -Encoding UTF8
if($changes -eq 0){Write-Host '[OK] No hay cambios recomendados.';exit 0}
$ans=Read-Host 'Aplicar estos ajustes? [S/N]'
if($ans -notmatch '^[Ss]'){Write-Host 'Sin cambios.';exit 0}
foreach($i in $items){Set-Dword $i.P $i.N ([int]$i.V)}
Write-Host '[OK] Ajustes aplicados.'
exit 0
