param(
 [ValidateSet('Show','Add')] [string]$Mode='Show',
 [Parameter(Mandatory=$true)] [string]$HistoryFile,
 [string]$Action='',
 [string]$Detail=''
)

$ErrorActionPreference='Stop'

function Ensure-Parent([string]$Path){
    $dir=Split-Path -Parent $Path
    if($dir -and -not (Test-Path -LiteralPath $dir)){
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

try{
    Ensure-Parent $HistoryFile

    if($Mode -eq 'Add'){
        $row=[pscustomobject]@{
            Time=(Get-Date).ToString('s')
            Action=$Action
            Detail=$Detail
        }

        $arr=@()
        if(Test-Path -LiteralPath $HistoryFile){
            try{
                $raw=Get-Content -LiteralPath $HistoryFile -Raw
                if($raw.Trim()){
                    $arr=@($raw | ConvertFrom-Json)
                }
            }catch{
                Write-Host '[AVISO] El historial anterior no pudo leerse. Se creara uno nuevo.'
                $arr=@()
            }
        }

        $arr += $row
        $json=$arr | ConvertTo-Json -Depth 5
        Set-Content -LiteralPath $HistoryFile -Value $json -Encoding UTF8 -ErrorAction Stop

        if(Test-Path -LiteralPath $HistoryFile){
            Write-Host '[OK] Cambio registrado.'
            exit 0
        }

        Write-Host '[ERROR] No se pudo confirmar la escritura del historial.'
        exit 2
    }

    if(-not (Test-Path -LiteralPath $HistoryFile)){
        $v=(& (Join-Path $PSScriptRoot 'Version.ps1') -Mode Display 2>$null); if(-not $v){$v=''}; Write-Host ('Todavia no hay cambios registrados por WinTool '+$v+'.')
        exit 0
    }

    $raw=Get-Content -LiteralPath $HistoryFile -Raw -ErrorAction Stop
    if(-not $raw.Trim()){
        Write-Host 'El historial esta vacio.'
        exit 0
    }

    $arr=@($raw | ConvertFrom-Json)
    Write-Host 'HISTORIAL DE CAMBIOS DE WINTOOL'
    Write-Host ''

    $arr |
      Sort-Object Time -Descending |
      Select-Object -First 40 |
      ForEach-Object {
        Write-Host ("{0}  {1}" -f $_.Time,$_.Action)
        if($_.Detail){Write-Host ("   "+$_.Detail)}
      }

    exit 0
}
catch{
    Write-Host ('[ERROR] No se pudo guardar/leer el historial: '+$_.Exception.Message)
    exit 2
}
