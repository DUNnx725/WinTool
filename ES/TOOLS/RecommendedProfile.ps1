param([Parameter(Mandatory=$true)][string]$BackupDir,[switch]$Restore)
$ErrorActionPreference='Stop'
$bk=Join-Path $BackupDir 'RecommendedProfile.json'
$items=@(
    @{Path='HKCU:\Software\Microsoft\GameBar';Name='AutoGameModeEnabled';Desired=1;Desc='Game Mode'},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR';Name='AppCaptureEnabled';Desired=0;Desc='Game DVR capturas'}
)
function Set-Dword([string]$Path,[string]$Name,[int]$Value){
    if(!(Test-Path $Path)){New-Item -Path $Path -Force|Out-Null}
    if($null -eq (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue)){
        New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force|Out-Null
    }else{Set-ItemProperty -Path $Path -Name $Name -Value $Value}
}
if($Restore){
    if(!(Test-Path $bk)){Write-Host '[INFO] No hay backup.';exit 0}
    $data=Get-Content $bk -Raw|ConvertFrom-Json
    foreach($x in $data){
        if([bool]$x.Exists){Set-Dword $x.Path $x.Name ([int]$x.Value)}
        else{Remove-ItemProperty -Path $x.Path -Name $x.Name -ErrorAction SilentlyContinue}
    }
    Write-Host '[OK] Perfil restaurado.';exit 0
}
$backup=@();$changes=0
foreach($i in $items){
    $prop=Get-ItemProperty -Path $i.Path -Name $i.Name -ErrorAction SilentlyContinue
    $exists=$null -ne $prop
    $v=if($exists){$prop.($i.Name)}else{$null}
    $backup+=@{Path=$i.Path;Name=$i.Name;Exists=$exists;Value=$v}
    $state=if($v -eq $i.Desired){'OK'}else{'REVISAR';$changes++}
    Write-Host ("[$state] $($i.Desc) | actual=$v | recomendado=$($i.Desired)")
}
$backup|ConvertTo-Json -Depth 4|Set-Content $bk -Encoding UTF8
if($changes -eq 0){Write-Host '[OK] No hay cambios recomendados.';exit 0}
$ans=Read-Host 'Aplicar solo los cambios REVISAR? [S/N]'
if($ans -notmatch '^[Ss]'){Write-Host 'Sin cambios.';exit 0}
foreach($i in $items){Set-Dword $i.Path $i.Name ([int]$i.Desired)}
Write-Host '[OK] Perfil aplicado. Reinicia los juegos abiertos.'
exit 0
