param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Init','Show')]
    [string]$Mode,
    [Parameter(Mandatory=$true)]
    [string]$BaseDir,
    [string]$ConfigFile=''
)
$ErrorActionPreference='Stop'

function EnsureDir([string]$Path){
    if(-not (Test-Path -LiteralPath $Path)){
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
    return (Test-Path -LiteralPath $Path)
}

$portableConfig = if($ConfigFile){$ConfigFile}else{Join-Path $BaseDir 'CONFIG\StorageMode.json'}
$root = Join-Path $env:LOCALAPPDATA 'WinTool'

$paths=[ordered]@{
    ROOT       = $root
    REPORTES   = (Join-Path $root 'REPORTES')
    BACKUPS    = (Join-Path $root 'BACKUPS')
    LOGS       = (Join-Path $root 'LOGS')
    CONFIG     = (Join-Path $root 'CONFIG')
    DRIVERS    = (Join-Path $root 'DESCARGAS_DRIVERS')
    COMPONENTS = (Join-Path $root 'COMPONENTES')
}

$failed=@()
foreach($k in $paths.Keys){
    if($k -eq 'ROOT'){continue}
    try{
        if(-not (EnsureDir $paths[$k])){$failed+=$k}
    }catch{$failed+=$k}
}

if($failed.Count -gt 0){
    Write-Host '[ERROR] WinTool no pudo preparar algunas carpetas de trabajo:'
    foreach($x in $failed){Write-Host (' - '+$x)}
    Write-Host ''
    Write-Host 'Windows puede estar bloqueando escrituras en una carpeta protegida.'
    Write-Host 'WinTool no necesita que desactives Seguridad de Windows.'
    exit 3
}

try{
    $stateFile=Join-Path $paths.CONFIG 'ResolvedPaths.json'
    [pscustomobject]@{
        Date=(Get-Date).ToString('s')
        BaseDir=$BaseDir
        Root=$root
        Paths=$paths
    }|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $stateFile -Encoding UTF8
}catch{}

if($Mode -eq 'Show'){
    Write-Host ('Datos de WinTool.......... '+$root)
    Write-Host ''
    foreach($k in 'REPORTES','BACKUPS','LOGS','CONFIG','DRIVERS','COMPONENTS'){
        Write-Host ('{0,-22} {1}' -f $k,$paths[$k])
    }
    exit 0
}

foreach($k in $paths.Keys){
    Write-Output ($k+'|'+$paths[$k])
}
exit 0
