param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Analyze','ApplyRecommended','Restore','OpenSettings')]
    [string]$Mode,
    [Parameter(Mandatory=$true)]
    [string]$BackupDir
)

$ErrorActionPreference='SilentlyContinue'
$dir=Join-Path $BackupDir 'PrivacyV54'
$file=Join-Path $dir 'EstadoAnterior.json'

function Ensure([string]$p){if(-not(Test-Path $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null}}
function State([string]$Path,[string]$Name){
    $e=$false;$v=$null;$k=$null
    try{
        if(Test-Path $Path){
            $rk=Get-Item $Path
            $v=$rk.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            if($null -ne $v){$e=$true;$k=$rk.GetValueKind($Name).ToString()}
        }
    }catch{}
    [pscustomobject]@{Path=$Path;Name=$Name;Exists=$e;Value=$v;Kind=$k}
}
function Put([string]$Path,[string]$Name,$Value,[Microsoft.Win32.RegistryValueKind]$Kind=[Microsoft.Win32.RegistryValueKind]::DWord){
    if(-not(Test-Path $Path)){New-Item -Path $Path -Force|Out-Null}
    (Get-Item $Path).SetValue($Name,$Value,$Kind)
}
function Restore($s){
    try{
        if($s.Exists){
            if(-not(Test-Path $s.Path)){New-Item -Path $s.Path -Force|Out-Null}
            (Get-Item $s.Path).SetValue($s.Name,$s.Value,[Microsoft.Win32.RegistryValueKind]::$($s.Kind))
        }elseif(Test-Path $s.Path){
            Remove-ItemProperty -Path $s.Path -Name $s.Name -ErrorAction SilentlyContinue
        }
    }catch{}
}

$items=@(
 @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo';Name='Enabled';Friendly='ID de publicidad'},
 @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy';Name='TailoredExperiencesWithDiagnosticDataEnabled';Friendly='Experiencias personalizadas'},
 @{Path='HKCU:\Software\Microsoft\InputPersonalization';Name='RestrictImplicitInkCollection';Friendly='Recopilacion de escritura manuscrita'},
 @{Path='HKCU:\Software\Microsoft\InputPersonalization';Name='RestrictImplicitTextCollection';Friendly='Recopilacion de escritura'},
 @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager';Name='SoftLandingEnabled';Friendly='Sugerencias de Windows'},
 @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager';Name='SystemPaneSuggestionsEnabled';Friendly='Recomendaciones en Inicio/Windows'}
)

$os=Get-CimInstance Win32_OperatingSystem
$edition=(Get-ComputerInfo -Property WindowsProductName -ErrorAction SilentlyContinue).WindowsProductName
$isPolicyEdition=($edition -match 'Pro|Enterprise|Education')

if($Mode -eq 'Analyze'){
    Write-Host 'PRIVACIDAD RECOMENDADA - ESTADO'
    Write-Host ''
    Write-Host ('Windows................ '+$os.Caption.Replace('Microsoft ','')+' Build '+$os.BuildNumber)
    foreach($i in $items){
        $s=State $i.Path $i.Name
        $txt='PREDETERMINADO'
        if($s.Exists){
            if($i.Name -match '^Restrict'){$txt=if([int]$s.Value -eq 1){'REDUCIDA'}else{'ACTIVA'}}
            else{$txt=if([int]$s.Value -eq 0){'DESACTIVADA'}else{'ACTIVA'}}
        }
        Write-Host (('{0,-29} {1}' -f ($i.Friendly+'.'),$txt))
    }
    $tele=State 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry'
    if($tele.Exists){
        $t=if([int]$tele.Value -le 1){'SOLO DATOS REQUERIDOS'}else{'MAS DATOS PERMITIDOS'}
    }else{$t='CONTROLADO POR WINDOWS / USUARIO'}
    Write-Host (('{0,-29} {1}' -f 'Diagnosticos de Windows.',$t))
    Write-Host (('{0,-29} {1}' -f 'Voz online.','SE REVISA DESDE CONFIGURACION'))
    Write-Host ''
    Write-Host 'Perfil recomendado: reduce publicidad, sugerencias, personalizacion y datos opcionales.'
    Write-Host 'No desactiva Windows Update, Defender, Buscar, Store ni servicios criticos.'
    exit 0
}

if($Mode -eq 'OpenSettings'){
    Start-Process 'ms-settings:privacy'
    exit 0
}

if($Mode -eq 'ApplyRecommended'){
    Ensure $dir
    if(-not(Test-Path $file)){
        $states=@()
        foreach($i in $items){$states+=State $i.Path $i.Name}
        $states+=State 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry'
        [pscustomobject]@{Date=(Get-Date).ToString('s');Registry=$states}|ConvertTo-Json -Depth 8|Set-Content $file -Encoding UTF8
    }
    Put 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
    Put 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
    Put 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection' 1
    Put 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' 1
    Put 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SoftLandingEnabled' 0
    Put 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SystemPaneSuggestionsEnabled' 0

    if($isPolicyEdition){
        # Microsoft documents 1 as Required diagnostic data.
        Put 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 1
        $diag='diagnosticos limitados a datos requeridos'
    }else{
        $diag='nivel de diagnosticos dejado bajo control de Windows (edicion sin politica aplicada)'
    }

    Write-Host '[OK] Privacidad recomendada aplicada.'
    Write-Host ('- '+$diag+';')
    Write-Host '- publicidad y experiencias personalizadas reducidas;'
    Write-Host '- recopilacion opcional de escritura/manuscrita reducida;'
    Write-Host '- sugerencias y recomendaciones de Windows reducidas.'
    Write-Host ''
    Write-Host 'Voz online y opciones nuevas de cada build quedan disponibles en Configuracion para evitar forzar claves no compatibles.'
    exit 0
}

if($Mode -eq 'Restore'){
    if(-not(Test-Path $file)){Write-Host '[INFO] No existe un backup de privacidad guardado por WinTool.';exit 0}
    try{$b=Get-Content $file -Raw|ConvertFrom-Json}catch{Write-Host '[ERROR] Backup ilegible.';exit 2}
    foreach($s in @($b.Registry)){Restore $s}
    Remove-Item $file -Force -ErrorAction SilentlyContinue
    Write-Host '[OK] Privacidad restaurada al estado guardado.'
    exit 0
}
