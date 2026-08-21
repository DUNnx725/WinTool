param(
    [Parameter(Mandatory=$true)][string]$ToolsDir,
    [Parameter(Mandatory=$true)][string]$LogFile,
    [string]$ReportsDir='',
    [string]$BackupsDir='',
    [string]$ConfigDir='',
    [string]$PresentMonPath='',
    [string]$BatFile=''
)

$ErrorActionPreference='Stop'
$lines=New-Object System.Collections.Generic.List[string]
$bad=0

function Add([string]$s){
    $script:lines.Add($s)
    Write-Host $s
}
function CheckDir([string]$p,[string]$name){
    if([string]::IsNullOrWhiteSpace($p)){ return }
    try{
        if(-not(Test-Path -LiteralPath $p)){
            New-Item -ItemType Directory -Path $p -Force | Out-Null
        }
        $probe=Join-Path $p ('.wintool_write_'+[guid]::NewGuid().ToString('N')+'.tmp')
        [IO.File]::WriteAllText($probe,'ok')
        Remove-Item -LiteralPath $probe -Force
        Add("[OK] $name disponible.")
    }catch{
        Add("[ERROR] $name no esta disponible para escritura.")
        $script:bad++
    }
}

$logDir=Split-Path -Parent $LogFile
if($logDir -and -not(Test-Path -LiteralPath $logDir)){
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

try{
    $v=(& (Join-Path $ToolsDir 'Version.ps1') -Mode Display 2>$null); if(-not $v){$v=''}; Add ('WINTOOL '+$v+' - AUTOVERIFICACION')
    Add ('PowerShell: '+$PSVersionTable.PSVersion.ToString())
    Add ('TOOLS: '+$ToolsDir)
    Add ''

    # Compatibilidad soportada.
    try{
        $os=Get-CimInstance Win32_OperatingSystem
        $caption=[string]$os.Caption
        if([Environment]::OSVersion.Version.Major -ge 10){
            Add('[OK] Sistema compatible: '+$caption)
        }else{
            Add('[ERROR] WinTool requiere Windows 10 u 11.')
            $bad++
        }
    }catch{
        Add('[REVISAR] No se pudo leer la version de Windows mediante CIM.')
    }
    if([Environment]::Is64BitOperatingSystem){
        Add '[OK] Arquitectura x64.'
    }else{
        Add '[ERROR] WinTool requiere Windows x64.'
        $bad++
    }

    Add ''
    Add 'Comprobando carpetas de trabajo...'
    CheckDir $ReportsDir 'REPORTES'
    CheckDir $BackupsDir 'BACKUPS'
    CheckDir $ConfigDir 'CONFIG'
    CheckDir $logDir 'LOGS'

    Add ''
    Add 'Comprobando scripts PowerShell...'
    $files=Get-ChildItem -LiteralPath $ToolsDir -Filter '*.ps1' -File | Sort-Object Name
    foreach($f in $files){
        $tokens=$null
        $errors=$null
        [void][System.Management.Automation.Language.Parser]::ParseFile(
            $f.FullName,[ref]$tokens,[ref]$errors
        )
        if($errors.Count -gt 0){
            $bad++
            Add ('[ERROR PS] '+$f.Name)
            foreach($e in $errors){
                Add ('  '+$e.Message+' | linea '+$e.Extent.StartLineNumber)
            }
        }
    }
    if($bad -eq 0){ Add '[OK] Sintaxis PowerShell verificada.' }

    Add ''
    Add 'Comprobando componentes necesarios...'
    $required=@(
        'UI.ps1','StartupStatus.ps1','Dashboard.ps1','ChangeHistory.ps1',
        'GamingProfileV54.ps1','PrivacyV54.ps1','PowerPlan.ps1','DnsManager.ps1',
        'WinAnalyzerV10.ps1','WinAnalyzerUIV1.ps1','WinAnalyzerCheckV10.ps1',
        'GameOptimizerV58.ps1','Version.ps1'
    )
    foreach($f in $required){
        $p=Join-Path $ToolsDir $f
        if(Test-Path -LiteralPath $p){
            Add("[OK] $f")
        }else{
            Add("[ERROR] Falta $f")
            $bad++
        }
    }

    if($PresentMonPath){
        if(Test-Path -LiteralPath $PresentMonPath){
            $expected='9bec3083069f58f911e6a512f4806db51a27bd096103087bc1d05ef54c80a191'
            try{
                $h=(Get-FileHash -LiteralPath $PresentMonPath -Algorithm SHA256).Hash.ToLowerInvariant()
                if($h -eq $expected){
                    Add '[OK] PresentMon 2.5.1 verificado por SHA-256.'
                }else{
                    Add '[ERROR] PresentMon no coincide con el componente verificado.'
                    $bad++
                }
            }catch{
                Add '[ERROR] No se pudo verificar el SHA-256 de PresentMon.'
                $bad++
            }
        }else{
            Add '[ERROR] PresentMon no encontrado.'
            $bad++
        }
    }

    # Se conserva el control estructural del BAT.
    if($BatFile){
        Add ''
        Add 'Comprobando estructura BAT...'
        if(Test-Path -LiteralPath $BatFile){
            $raw=Get-Content -LiteralPath $BatFile
            $labels=@{}
            foreach($line in $raw){
                if($line -match '^\s*:([A-Za-z0-9_]+)\s*$'){
                    $key=$matches[1].ToUpperInvariant()
                    if($labels.ContainsKey($key)){
                        Add('[ERROR BAT] Etiqueta duplicada: '+$key)
                        $bad++
                    }else{
                        $labels[$key]=$true
                    }
                }
            }
            foreach($line in $raw){
                if($line -match '(?i)\bgoto\s+([A-Za-z0-9_]+)'){
                    $g=$matches[1].ToUpperInvariant()
                    if(-not $labels.ContainsKey($g)){
                        Add('[ERROR BAT] GOTO sin destino: '+$g)
                        $bad++
                    }
                }
                if($line -match '(?i)^\s*if\s+errorlevel.+&\s*(goto|pause|start|powershell|cmd)'){
                    Add('[ERROR BAT] IF ERRORLEVEL con comandos encadenados: '+$line.Trim())
                    $bad++
                }
            }
            if($bad -eq 0){ Add '[OK] Estructura BAT verificada.' }
        }else{
            Add '[ERROR BAT] No se encontro el BAT principal.'
            $bad++
        }
    }

    Add ''
    if($bad -eq 0){
        Add '[OK] Autoverificacion completada sin errores bloqueantes.'
        $rc=0
    }else{
        Add('[ERROR] Problemas detectados: '+$bad)
        $rc=2
    }

    [IO.File]::WriteAllLines($LogFile,$lines,(New-Object Text.UTF8Encoding($false)))
    exit $rc
}catch{
    Add('[ERROR] '+$_.Exception.Message)
    try{[IO.File]::WriteAllLines($LogFile,$lines,(New-Object Text.UTF8Encoding($false)))}catch{}
    exit 3
}
