param(
    [ValidateSet('Show','Balanced','High','Max','Restore')]
    [string]$Mode='Show',
    [string]$BackupFile=''
)
$ErrorActionPreference='SilentlyContinue'

$BalancedGuid='381b4222-f694-41f0-9685-ff5bb260df2e'
$HighGuid='8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
$UltimateTemplate='e9a42b02-d5df-448d-aa00-03f14749eb61'

function ActiveGuid {
    $txt=powercfg /getactivescheme | Out-String
    $m=[regex]::Match($txt,'[0-9a-fA-F-]{36}')
    if($m.Success){ return $m.Value.ToLowerInvariant() }
    return $null
}
function ActiveName {
    $txt=powercfg /getactivescheme | Out-String
    $m=[regex]::Match($txt,'\(([^)]+)\)')
    if($m.Success){ return $m.Groups[1].Value }
    return 'Plan desconocido'
}
function SaveOriginal {
    if([string]::IsNullOrWhiteSpace($BackupFile)){ return }
    if(-not(Test-Path -LiteralPath $BackupFile)){
        $dir=Split-Path -Parent $BackupFile
        if($dir -and -not(Test-Path -LiteralPath $dir)){
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        $g=ActiveGuid
        if($g){
            [pscustomobject]@{
                Guid=$g
                Name=(ActiveName)
                SavedAt=(Get-Date).ToString('o')
            } | ConvertTo-Json | Set-Content -LiteralPath $BackupFile -Encoding UTF8
        }
    }
}
function FindOrCreate([string]$Guid,[string]$NamePattern){
    $list=powercfg /list | Out-String
    $lines=$list -split "`r?`n"
    $line=$lines | Where-Object {$_ -match $Guid -or $_ -match $NamePattern} | Select-Object -First 1
    $g=[regex]::Match([string]$line,'[0-9a-fA-F-]{36}').Value
    if($g){ return $g }
    $created=powercfg /duplicatescheme $Guid 2>$null | Out-String
    $g=[regex]::Match($created,'[0-9a-fA-F-]{36}').Value
    return $g
}
function Activate([string]$Guid,[string]$Friendly){
    if(-not $Guid){
        Write-Host ('[REVISAR] No se pudo localizar o crear el plan '+$Friendly+'.')
        exit 2
    }
    SaveOriginal
    powercfg /setactive $Guid | Out-Null
    if((ActiveGuid) -eq $Guid.ToLowerInvariant()){
        Write-Host ('[OK] Plan activo: '+$Friendly+'.')
        exit 0
    }
    Write-Host ('[REVISAR] Windows no confirmo el cambio al plan '+$Friendly+'.')
    exit 2
}

if($Mode -eq 'Show'){
    Write-Host ('Plan actual............ '+(ActiveName))
    exit 0
}
if($Mode -eq 'Restore'){
    if([string]::IsNullOrWhiteSpace($BackupFile) -or -not(Test-Path -LiteralPath $BackupFile)){
        Write-Host '[INFO] No hay un plan anterior guardado por WinTool.'
        exit 0
    }
    try{$b=Get-Content -LiteralPath $BackupFile -Raw | ConvertFrom-Json}catch{
        Write-Host '[REVISAR] El backup del plan de energia no se pudo leer.'
        exit 2
    }
    if($b.Guid){
        powercfg /setactive ([string]$b.Guid) | Out-Null
        if((ActiveGuid) -eq ([string]$b.Guid).ToLowerInvariant()){
            Write-Host ('[OK] Plan anterior restaurado: '+$(if($b.Name){$b.Name}else{$b.Guid})+'.')
            Remove-Item -LiteralPath $BackupFile -Force -ErrorAction SilentlyContinue
            exit 0
        }
    }
    Write-Host '[REVISAR] No se pudo restaurar el plan anterior.'
    exit 2
}
if($Mode -eq 'Balanced'){
    Activate $BalancedGuid 'Equilibrado'
}
if($Mode -eq 'High'){
    $g=FindOrCreate $HighGuid 'Alto rendimiento|High performance'
    Activate $g 'Alto rendimiento'
}
if($Mode -eq 'Max'){
    $list=powercfg /list | Out-String
    $line=($list -split "`r?`n" | Where-Object {$_ -match 'Maximo rendimiento|Máximo rendimiento|Ultimate Performance'} | Select-Object -First 1)
    $g=[regex]::Match([string]$line,'[0-9a-fA-F-]{36}').Value
    if(-not $g){
        $created=powercfg /duplicatescheme $UltimateTemplate 2>$null | Out-String
        $g=[regex]::Match($created,'[0-9a-fA-F-]{36}').Value
    }
    Activate $g 'Maximo rendimiento'
}
