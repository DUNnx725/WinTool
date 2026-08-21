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
 @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo';Name='Enabled';Friendly='Advertising ID'},
 @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy';Name='TailoredExperiencesWithDiagnosticDataEnabled';Friendly='Tailored experiences'},
 @{Path='HKCU:\Software\Microsoft\InputPersonalization';Name='RestrictImplicitInkCollection';Friendly='Inking data collection'},
 @{Path='HKCU:\Software\Microsoft\InputPersonalization';Name='RestrictImplicitTextCollection';Friendly='Typing data collection'},
 @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager';Name='SoftLandingEnabled';Friendly='Windows suggestions'},
 @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager';Name='SystemPaneSuggestionsEnabled';Friendly='Recommendations in Start/Windows'}
)

$os=Get-CimInstance Win32_OperatingSystem
$edition=(Get-ComputerInfo -Property WindowsProductName -ErrorAction SilentlyContinue).WindowsProductName
$isPolicyEdition=($edition -match 'Pro|Enterprise|Education')

if($Mode -eq 'Analyze'){
    Write-Host 'RECOMMENDED PRIVACY - STATUS'
    Write-Host ''
    Write-Host ('Windows................ '+$os.Caption.Replace('Microsoft ','')+' Build '+$os.BuildNumber)
    foreach($i in $items){
        $s=State $i.Path $i.Name
        $txt='DEFAULT'
        if($s.Exists){
            if($i.Name -match '^Restrict'){$txt=if([int]$s.Value -eq 1){'REDUCED'}else{'ENABLED'}}
            else{$txt=if([int]$s.Value -eq 0){'DISABLED'}else{'ENABLED'}}
        }
        Write-Host (('{0,-29} {1}' -f ($i.Friendly+'.'),$txt))
    }
    $tele=State 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry'
    if($tele.Exists){
        $t=if([int]$tele.Value -le 1){'REQUIRED DATA ONLY'}else{'MORE DATA ALLOWED'}
    }else{$t='CONTROLLED BY WINDOWS / USER'}
    Write-Host (('{0,-29} {1}' -f 'Windows diagnostics.',$t))
    Write-Host (('{0,-29} {1}' -f 'Online speech.','CHECK IN WINDOWS SETTINGS'))
    Write-Host ''
    Write-Host 'Recommended profile: reduces advertising, suggestions, personalization and optional data.'
    Write-Host 'Does not disable Windows Update, Defender, Search, Store or critical services.'
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
        $diag='diagnostics limited to required data'
    }else{
        $diag='diagnostic level left under Windows control (edition without policy applied)'
    }

    Write-Host '[OK] Recommended privacy settings applied.'
    Write-Host ('- '+$diag+';')
    Write-Host '- advertising and tailored experiences reduced;'
    Write-Host '- optional typing/inking collection reduced;'
    Write-Host '- Windows suggestions and recommendations reduced.'
    Write-Host ''
    Write-Host 'Online speech and build-specific options remain available in Windows Settings to avoid forcing unsupported registry values.'
    exit 0
}

if($Mode -eq 'Restore'){
    if(-not(Test-Path $file)){Write-Host '[INFO] No privacy backup saved by WinTool was found.';exit 0}
    try{$b=Get-Content $file -Raw|ConvertFrom-Json}catch{Write-Host '[ERROR] Backup could not be read.';exit 2}
    foreach($s in @($b.Registry)){Restore $s}
    Remove-Item $file -Force -ErrorAction SilentlyContinue
    Write-Host '[OK] Privacy settings restored to the saved state.'
    exit 0
}
