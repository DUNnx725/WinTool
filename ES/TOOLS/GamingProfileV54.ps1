param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Analyze','Apply','Restore')]
    [string]$Mode,
    [Parameter(Mandatory=$true)]
    [string]$BackupDir
)

$ErrorActionPreference='SilentlyContinue'
$profileDir=Join-Path $BackupDir 'GamingV54'
$backupFile=Join-Path $profileDir 'EstadoAnterior.json'

function Ensure([string]$p){
    if(-not (Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null}
}
function ActiveGuid {
    $m=[regex]::Match((powercfg /getactivescheme|Out-String),'[0-9a-fA-F-]{36}')
    if($m.Success){return $m.Value}
    return $null
}
function RegState([string]$Path,[string]$Name){
    $exists=$false;$value=$null;$kind=$null
    try{
        if(Test-Path -LiteralPath $Path){
            $key=Get-Item -LiteralPath $Path
            $value=$key.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            if($null -ne $value){$exists=$true;$kind=$key.GetValueKind($Name).ToString()}
        }
    }catch{}
    [pscustomobject]@{Path=$Path;Name=$Name;Exists=$exists;Value=$value;Kind=$kind}
}
function SetReg([string]$Path,[string]$Name,$Value,[Microsoft.Win32.RegistryValueKind]$Kind=[Microsoft.Win32.RegistryValueKind]::DWord){
    if(-not (Test-Path $Path)){New-Item -Path $Path -Force|Out-Null}
    $k=Get-Item $Path
    $k.SetValue($Name,$Value,$Kind)
}
function RestoreReg($s){
    try{
        if($s.Exists){
            if(-not (Test-Path $s.Path)){New-Item -Path $s.Path -Force|Out-Null}
            $kind=[Microsoft.Win32.RegistryValueKind]::$($s.Kind)
            (Get-Item $s.Path).SetValue($s.Name,$s.Value,$kind)
        }elseif(Test-Path $s.Path){
            Remove-ItemProperty -Path $s.Path -Name $s.Name -ErrorAction SilentlyContinue
        }
    }catch{}
}
function PowerPlanExists([string]$Guid){
    if(-not $Guid){return $false}
    return ((powercfg /list|Out-String) -match [regex]::Escape($Guid))
}

function PlanName([string]$Guid){
    if(-not $Guid){return ''}
    $line=((powercfg /list|Out-String) -split "`r?`n" | Where-Object {$_ -match [regex]::Escape($Guid)} | Select-Object -First 1)
    $m=[regex]::Match([string]$line,'\(([^)]+)\)')
    if($m.Success){return $m.Groups[1].Value}
    return ''
}
function FindUltimatePerformanceGuid {
    # Prefer the built-in Ultimate Performance GUID when it exists.
    $official='e9a42b02-d5df-448d-aa00-03f14749eb61'
    if(PowerPlanExists $official){return $official}

    # Otherwise reuse an existing Windows Ultimate Performance scheme, including localized names.
    $lines=(powercfg /list|Out-String) -split "`r?`n"
    foreach($line in $lines){
        if($line -match 'Maximo rendimiento|Máximo rendimiento|Ultimate Performance'){
            $m=[regex]::Match($line,'[0-9a-fA-F-]{36}')
            if($m.Success){return $m.Value}
        }
    }

    # If Windows has the template but no listed scheme, ask Windows to create its own scheme.
    # Do not rename it and do not change any power-setting values.
    $out=powercfg /duplicatescheme $official 2>$null | Out-String
    $m=[regex]::Match($out,'[0-9a-fA-F-]{36}')
    if($m.Success){return $m.Value}
    return $null
}

$regs=@(
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize';Name='EnableTransparency'},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects';Name='VisualFXSetting'},
    @{Path='HKCU:\Control Panel\Desktop\WindowMetrics';Name='MinAnimate'},
    @{Path='HKCU:\System\GameConfigStore';Name='GameDVR_Enabled'},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR';Name='AppCaptureEnabled'},
    @{Path='HKCU:\Software\Microsoft\GameBar';Name='AutoGameModeEnabled'}
)

if($Mode -eq 'Analyze'){
    $os=Get-CimInstance Win32_OperatingSystem
    $trans=(RegState $regs[0].Path $regs[0].Name)
    $visual=(RegState $regs[1].Path $regs[1].Name)
    $dvr=(RegState $regs[3].Path $regs[3].Name)
    $cap=(RegState $regs[4].Path $regs[4].Name)
    $gm=(RegState $regs[5].Path $regs[5].Name)

    Write-Host 'PERFIL GAMING - ANALISIS'
    Write-Host ''
    Write-Host ('Windows................ '+$os.Caption.Replace('Microsoft ','')+' Build '+$os.BuildNumber)
    Write-Host ('Plan de energia........ '+(powercfg /getactivescheme|Out-String).Trim())
    Write-Host ('Transparencias......... '+$(if($trans.Exists -and [int]$trans.Value -eq 0){'DESACTIVADAS'}else{'ACTIVAS / PREDETERMINADAS'}))
    Write-Host ('Efectos visuales....... '+$(if($visual.Exists -and [int]$visual.Value -eq 2){'PRIORIZA RENDIMIENTO'}else{'NORMALES / PERSONALIZADOS'}))
    Write-Host ('Grabacion Game DVR..... '+$(if(($dvr.Exists -and [int]$dvr.Value -eq 0) -or ($cap.Exists -and [int]$cap.Value -eq 0)){'DESACTIVADA'}else{'ACTIVA / PREDETERMINADA'}))
    Write-Host ('Game Mode.............. '+$(if($gm.Exists -and [int]$gm.Value -eq 1){'ACTIVO'}else{'PREDETERMINADO'}))
    Write-Host ''
    Write-Host 'El perfil Maximo Rendimiento puede:'
    Write-Host '- desactivar transparencias y animacion de ventanas;'
    Write-Host '- orientar efectos visuales a rendimiento;'
    Write-Host '- desactivar grabacion Game DVR en segundo plano;'
    Write-Host '- activar Game Mode;'
    Write-Host '- usar Maximo rendimiento de Windows;'
    Write-Host '- no modifica valores internos del plan de energia de Windows.'
    Write-Host ''
    Write-Host 'No cambia prioridades, afinidades, HPET, BCD, pagefile, MSI Mode ni servicios criticos.'
    exit 0
}

if($Mode -eq 'Apply'){
    Ensure $profileDir

    if(-not (Test-Path $backupFile)){
        $states=@()
        foreach($r in $regs){$states+=RegState $r.Path $r.Name}
        $backup=[pscustomobject]@{
            Date=(Get-Date).ToString('s')
            ActivePowerGuid=(ActiveGuid)
            CreatedGamingGuid=$null
            Registry=$states
        }
        $backup|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $backupFile -Encoding UTF8
    }

    $backup=Get-Content -LiteralPath $backupFile -Raw|ConvertFrom-Json

    # User interface: lighter visuals.
    SetReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0
    SetReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 2
    SetReg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' ([Microsoft.Win32.RegistryValueKind]::String)

    # Gaming settings.
    SetReg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
    SetReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
    SetReg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1

    # Energy: use Windows Ultimate Performance without changing its internal values.
    # Public build: do not create or rename a "WinTool Gaming" plan.
    $ultimateGuid=FindUltimatePerformanceGuid
    if($ultimateGuid){
        powercfg /setactive $ultimateGuid | Out-Null
    }else{
        Write-Host '[REVISAR] Windows no pudo localizar o crear Maximo rendimiento.'
        Write-Host '[INFO] El resto del Perfil Gaming se aplico sin modificar el plan de energia.'
    }

    # Refresh user parameters. Some visual changes may need sign-out/restart Explorer.
    rundll32.exe user32.dll,UpdatePerUserSystemParameters 1,True | Out-Null

    Write-Host '[OK] Perfil Gaming aplicado.'
    Write-Host ''
    Write-Host 'Cambios principales:'
    Write-Host '- interfaz mas ligera;'
    Write-Host '- grabacion Game DVR desactivada;'
    Write-Host '- Game Mode activado;'
    Write-Host '- Maximo rendimiento de Windows seleccionado cuando esta disponible;'
    Write-Host '- el plan de energia se conserva con sus valores oficiales de Windows.'
    Write-Host ''
    Write-Host 'Puede aumentar consumo y temperatura. Algunos cambios visuales se completan al volver a iniciar sesion.'
    exit 0
}

if($Mode -eq 'Restore'){
    if(-not (Test-Path $backupFile)){
        Write-Host '[INFO] No existe un backup del Perfil Gaming.'
        exit 0
    }
    try{$backup=Get-Content -LiteralPath $backupFile -Raw|ConvertFrom-Json}catch{
        Write-Host '[ERROR] No se pudo leer el backup.'
        exit 2
    }
    foreach($s in @($backup.Registry)){RestoreReg $s}
    if($backup.ActivePowerGuid -and (PowerPlanExists ([string]$backup.ActivePowerGuid))){
        powercfg /setactive $backup.ActivePowerGuid | Out-Null
    }
    # Compatibility with backups created by earlier development builds:
    # delete only the legacy custom plan if it is explicitly named "WinTool Gaming".
    if($backup.CreatedGamingGuid -and (PowerPlanExists ([string]$backup.CreatedGamingGuid))){
        $legacyGuid=[string]$backup.CreatedGamingGuid
        $legacyName=PlanName $legacyGuid
        if($legacyName -eq 'WinTool Gaming'){
            powercfg /delete $legacyGuid | Out-Null
        }
    }
    rundll32.exe user32.dll,UpdatePerUserSystemParameters 1,True | Out-Null
    Remove-Item -LiteralPath $backupFile -Force -ErrorAction SilentlyContinue
    Write-Host '[OK] Perfil Gaming restaurado al estado guardado.'
    exit 0
}
