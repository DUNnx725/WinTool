param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Analyze','Last','History','Info','Component')]
    [string]$Mode,
    [Parameter(Mandatory=$true)][string]$PresentMonPath,
    [Parameter(Mandatory=$true)][string]$ReportsRoot,
    [Parameter(Mandatory=$true)][string]$ConfigDir,
    [string]$BackupsDir='',
    [string]$ToolsDir='',
    [string]$UiScript=''
)

$ErrorActionPreference='SilentlyContinue'
$ExpectedSha='9bec3083069f58f911e6a512f4806db51a27bd096103087bc1d05ef54c80a191'
$ExpectedVersion='2.5.1'

function WAHeader {
    Clear-Host
    if($UiScript -and (Test-Path -LiteralPath $UiScript)){
        & $UiScript -Mode Header
    }else{
        Write-Host '============================================================================================'
        Write-Host '                                      WinAnalyzer V1.0'
        Write-Host '============================================================================================'
        Write-Host ''
    }
}
function ValText($v,[string]$Suffix=''){
    if($null -eq $v){return 'NOT AVAILABLE'}
    return ((F1 $v)+$Suffix)
}
function ENState($v){
    $t=[string]$v
    switch($t){
        'NOT AVAILABLE' {return 'NOT AVAILABLE'}
        'BUENA' {return 'GOOD'}
        'ACEPTABLE' {return 'ACCEPTABLE'}
        'REVISAR' {return 'CHECK'}
        'ALTO' {return 'HIGH'}
        'NORMAL' {return 'NORMAL'}
        'SIN ALERTA' {return 'NO ALERT'}
        default {return $t}
    }
}
function ENResult($v){
    $t=[string]$v
    switch($t){
        'MIXTO / EQUILIBRADO' {return 'MIXED / BALANCED'}
        'SIN LIMITACION CLARA' {return 'NO CLEAR LIMITATION'}
        'PRUEBA NO CONCLUYENTE' {return 'INCONCLUSIVE TEST'}
        default {return $t}
    }
}
function ENConfidence($v){
    $t=[string]$v
    switch($t){
        'ALTA' {return 'HIGH'}
        'MEDIA' {return 'MEDIUM'}
        'BAJA' {return 'LOW'}
        default {return $t}
    }
}
function Fluidity($pm){
    if(-not $pm.Available -or $null -eq $pm.AvgFps -or $null -eq $pm.Low1 -or $pm.AvgFps -le 0){return 'NOT AVAILABLE'}
    $ratio=[double]$pm.Low1/[double]$pm.AvgFps
    if($ratio -ge 0.70){return 'BUENA'}
    if($ratio -ge 0.50){return 'ACEPTABLE'}
    return 'REVISAR'
}
function ENSignature($v){
    $t=[string]$v
    if($t -match 'Valid|Valida|Válida'){return 'VALID'}
    if($t -match 'NotSigned|No firmado|Sin firma'){return 'NOT SIGNED'}
    if([string]::IsNullOrWhiteSpace($t)){return 'UNKNOWN'}
    return $t
}
function GamingProfileActive {
    try{
        if(-not $BackupsDir){return $false}
        $marker=Join-Path $BackupsDir 'GamingV54\EstadoAnterior.json'
        return (Test-Path -LiteralPath $marker)
    }catch{return $false}
}
function StatusFromPct($v,[double]$Review,[double]$High){
    if($null -eq $v){return 'NOT AVAILABLE'}
    if([double]$v -ge $High){return 'ALTO'}
    if([double]$v -ge $Review){return 'REVISAR'}
    return 'NORMAL'
}

function Ensure([string]$p){
    if(-not(Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null}
}
function Avg($a){
    $v=@($a|Where-Object {$null -ne $_ -and "$_" -ne ''})
    if($v.Count -eq 0){return $null}
    return [double](($v|Measure-Object -Average).Average)
}
function Pct($a,[double]$p){
    $v=@($a|Where-Object {$null -ne $_ -and "$_" -ne ''}|ForEach-Object{[double]$_}|Sort-Object)
    if($v.Count -eq 0){return $null}
    $idx=[math]::Ceiling(($p/100.0)*$v.Count)-1
    $idx=[math]::Max(0,[math]::Min($v.Count-1,$idx))
    return [double]$v[$idx]
}
function F1($v){
    if($null -eq $v){return 'NOT AVAILABLE'}
    return ('{0:N1}' -f [double]$v)
}
function Mb($bytes){
    if($null -eq $bytes){return $null}
    return [math]::Round(([double]$bytes/1MB),1)
}
function VerifyPresentMon {
    $r=[ordered]@{Exists=$false;HashOk=$false;Sha='';Version='';Signature='NO COMPROBADA'}
    if(-not(Test-Path -LiteralPath $PresentMonPath)){return [pscustomobject]$r}
    $r.Exists=$true
    try{
        $r.Sha=(Get-FileHash -LiteralPath $PresentMonPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $r.HashOk=($r.Sha -eq $ExpectedSha)
    }catch{}
    try{
        $vi=[Diagnostics.FileVersionInfo]::GetVersionInfo($PresentMonPath)
        $r.Version=$vi.FileVersion
        if(-not $r.Version){$r.Version=$vi.ProductVersion}
    }catch{}
    try{
        $sig=Get-AuthenticodeSignature -LiteralPath $PresentMonPath
        if($sig){$r.Signature=$sig.Status.ToString()}
    }catch{}
    return [pscustomobject]$r
}
function FriendlyName([Diagnostics.Process]$p){
    $n=$p.ProcessName
    $map=@{
        'cs2'='Counter-Strike 2'
        'csgo'='Counter-Strike'
        'FortniteClient-Win64-Shipping'='Fortnite'
        'GTA5'='Grand Theft Auto V'
        'GTA5_Enhanced'='Grand Theft Auto V'
        'javaw'='Minecraft / Java application'
        'Minecraft.Windows'='Minecraft for Windows'
        'VALORANT-Win64-Shipping'='VALORANT'
        'RocketLeague'='Rocket League'
        'Overwatch'='Overwatch'
        'r5apex'='Apex Legends'
    }
    if($map.ContainsKey($n)){return $map[$n]}
    if($p.MainWindowTitle){return $p.MainWindowTitle}
    return $n
}
function GetGpuPids {
    $set=@{}
    try{
        $eng=Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine
        foreach($e in $eng){
            if([double]$e.UtilizationPercentage -ge 0.5 -and $e.Name -match 'pid_(\d+)_'){
                $set[[int]$matches[1]]=$true
            }
        }
    }catch{}
    return $set
}
function CandidateProcesses {
    $exclude='^(cmd|powershell|pwsh|explorer|taskmgr|SearchHost|StartMenuExperienceHost|ShellExperienceHost|SystemSettings|ApplicationFrameHost|TextInputHost|LockApp|SecurityHealthSystray|WinTool)'
    $gpuPids=GetGpuPids
    $procs=@()
    foreach($p in Get-Process -ErrorAction SilentlyContinue){
        try{
            if($p.Id -eq $PID){continue}
            if($p.ProcessName -match $exclude){continue}
            if($p.MainWindowHandle -eq 0 -and -not $gpuPids.ContainsKey($p.Id)){continue}
            $score=0
            if($gpuPids.ContainsKey($p.Id)){$score+=100}
            if($p.MainWindowHandle -ne 0){$score+=20}
            $procs += [pscustomobject]@{
                PID=$p.Id
                Name=$p.ProcessName
                Friendly=(FriendlyName $p)
                GpuActive=$gpuPids.ContainsKey($p.Id)
                Score=$score
            }
        }catch{}
    }
    return @($procs|Sort-Object Score,Name -Descending|Select-Object -First 15)
}
function ReadTarget {
    Write-Host ''
    Write-Host 'SEARCHING FOR GAMES / 3D APPLICATIONS...'
    Start-Sleep -Milliseconds 600
    $c=@(CandidateProcesses)
    if($c.Count -gt 0){
        Write-Host ''
        for($i=0;$i -lt $c.Count;$i++){
            $mark=if($c[$i].GpuActive){'GPU active'}else{'window open'}
            Write-Host ('[{0}] {1}  ({2}.exe, PID {3}) - {4}' -f ($i+1),$c[$i].Friendly,$c[$i].Name,$c[$i].PID,$mark)
        }
        Write-Host '[M] Select manually by PID'
        Write-Host '[C] Cancel'
        while($true){
            $sel=(Read-Host 'Select the game').Trim()
            if($sel -match '^[Cc]$'){return $null}
            if($sel -match '^[Mm]$'){
                $manual=Read-Host 'Game PID'
                if($manual -match '^\d+$'){
                    try{
                        $p=Get-Process -Id ([int]$manual) -ErrorAction Stop
                        return [pscustomobject]@{PID=$p.Id;Name=$p.ProcessName;Friendly=(FriendlyName $p)}
                    }catch{Write-Host '[CHECK] That PID does not exist.'}
                }
                continue
            }
            if($sel -match '^\d+$'){
                $n=[int]$sel
                if($n -ge 1 -and $n -le $c.Count){return $c[$n-1]}
            }
            Write-Host '[CHECK] Invalid option.'
        }
    }
    Write-Host '[INFO] No candidates were detected automatically.'
    $manual=Read-Host 'Enter the game PID, or C to cancel'
    if($manual -match '^[Cc]$'){return $null}
    if($manual -match '^\d+$'){
        try{
            $p=Get-Process -Id ([int]$manual) -ErrorAction Stop
            return [pscustomobject]@{PID=$p.Id;Name=$p.ProcessName;Friendly=(FriendlyName $p)}
        }catch{}
    }
    return $null
}
function ReadDuration {
    Write-Host ''
    Write-Host 'DURATION'
    Write-Host '[1] Quick          30 seconds'
    Write-Host '[2] Recommended    90 seconds'
    Write-Host '[3] Long          180 seconds'
    while($true){
        $d=(Read-Host 'Choose').Trim()
        if($d -eq '1'){return 30}
        if($d -eq '2'){return 90}
        if($d -eq '3'){return 180}
        Write-Host '[CHECK] Choose 1, 2 or 3.'
    }
}
function GetGpuEnginePct([int]$TargetPid){
    try{
        $eng=Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine |
            Where-Object {$_.Name -match ('pid_'+$TargetPid+'_') -and $_.Name -match 'engtype_(3D|Graphics|Compute)'}
        if(-not $eng){return $null}
        $s=0.0
        foreach($e in $eng){$s += [double]$e.UtilizationPercentage}
        return [math]::Min(100,[math]::Max(0,$s))
    }catch{return $null}
}
function GetGpuMemory([int]$TargetPid){
    try{
        $m=Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUProcessMemory |
           Where-Object {$_.Name -match ('pid_'+$TargetPid+'_')}
        if(-not $m){return [pscustomobject]@{Dedicated=$null;Shared=$null}}
        $d=[double]0;$s=[double]0
        foreach($x in $m){$d += [double]$x.DedicatedUsage;$s += [double]$x.SharedUsage}
        return [pscustomobject]@{Dedicated=$d;Shared=$s}
    }catch{return [pscustomobject]@{Dedicated=$null;Shared=$null}}
}
function SnapshotSystem([int]$TargetPid,[double]$PrevCpu,[datetime]$PrevTime){
    $now=Get-Date
    $proc=$null
    try{$proc=Get-Process -Id $TargetPid -ErrorAction Stop}catch{return $null}
    $logical=[Environment]::ProcessorCount
    $cpuSec=[double]$proc.TotalProcessorTime.TotalSeconds
    $dt=[math]::Max(0.1,($now-$PrevTime).TotalSeconds)
    $procCpu=[math]::Max(0,[math]::Min(100,(($cpuSec-$PrevCpu)/$dt/$logical)*100))
    $cpuAll=$null;$maxCore=$null
    try{
        $cores=@(Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor)
        $total=$cores|Where-Object Name -eq '_Total'|Select-Object -First 1
        if($total){$cpuAll=[double]$total.PercentProcessorTime}
        $per=@($cores|Where-Object Name -ne '_Total'|ForEach-Object{[double]$_.PercentProcessorTime})
        if($per.Count -gt 0){$maxCore=($per|Measure-Object -Maximum).Maximum}
    }catch{}
    $os=Get-CimInstance Win32_OperatingSystem
    $cs=Get-CimInstance Win32_ComputerSystem
    $ramPct=$null
    if($cs.TotalPhysicalMemory){$ramPct=(1-(($os.FreePhysicalMemory*1KB)/$cs.TotalPhysicalMemory))*100}
    $gm=GetGpuMemory $TargetPid
    $diskPct=$null
    try{
        $pd=Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk | Where-Object Name -eq '_Total' | Select-Object -First 1
        if($pd){$diskPct=[math]::Min(100,[double]$pd.PercentDiskTime)}
    }catch{}
    [pscustomobject]@{
        Time=$now
        CpuSec=$cpuSec
        ProcCpu=$procCpu
        CpuTotal=$cpuAll
        MaxCore=$maxCore
        GpuEngine=(GetGpuEnginePct $TargetPid)
        RamPct=$ramPct
        DiskPct=$diskPct
        GameRam=[double]$proc.WorkingSet64
        Dedicated=$gm.Dedicated
        Shared=$gm.Shared
    }
}
function ParsePresentMon([string]$Csv,[int]$TargetPid){
    $r=[ordered]@{
        Available=$false;Frames=0;AvgFps=$null;Low1=$null;MinFps=$null;AvgFrameMs=$null;MedianFrameMs=$null;P95FrameMs=$null;MaxFrameMs=$null;
        AvgGpuBusyPct=$null;AvgGpuBusyMs=$null;AvgCpuBusyMs=$null
    }
    if(-not(Test-Path -LiteralPath $Csv)){return [pscustomobject]$r}
    try{$rows=@(Import-Csv -LiteralPath $Csv)}catch{return [pscustomobject]$r}
    if($rows.Count -eq 0){return [pscustomobject]$r}
    if($rows[0].PSObject.Properties.Name -contains 'ProcessID'){
        $rows=@($rows|Where-Object {[int]$_.ProcessID -eq $TargetPid})
    }
    $frameCol=if($rows.Count -gt 0 -and $rows[0].PSObject.Properties.Name -contains 'MsBetweenPresents'){'MsBetweenPresents'}else{$null}
    if(-not $frameCol){return [pscustomobject]$r}
    $frames=New-Object System.Collections.Generic.List[double]
    $gpuRatios=New-Object System.Collections.Generic.List[double]
    $gpuMs=New-Object System.Collections.Generic.List[double]
    $cpuMs=New-Object System.Collections.Generic.List[double]
    foreach($x in $rows){
        $fm=0.0
        if([double]::TryParse([string]$x.$frameCol,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$fm)){
            if($fm -gt 0 -and $fm -le 1000){
                $frames.Add($fm)
                if($x.PSObject.Properties.Name -contains 'MsGPUBusy'){
                    $gb=0.0
                    if([double]::TryParse([string]$x.MsGPUBusy,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$gb)){
                        if($gb -ge 0){$gpuMs.Add($gb);$gpuRatios.Add([math]::Min(100,($gb/$fm)*100))}
                    }
                }
                if($x.PSObject.Properties.Name -contains 'MsCPUBusy'){
                    $cb=0.0
                    if([double]::TryParse([string]$x.MsCPUBusy,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$cb)){
                        if($cb -ge 0){$cpuMs.Add($cb)}
                    }
                }
            }
        }
    }
    if($frames.Count -lt 2){return [pscustomobject]$r}
    $avgFrame=Avg $frames
    $sortedWorst=@($frames|Sort-Object -Descending)
    $worstCount=[math]::Max(1,[math]::Ceiling($sortedWorst.Count*0.01))
    $worst=@($sortedWorst|Select-Object -First $worstCount)
    $worstAvg=Avg $worst
    $r.Available=$true
    $r.Frames=$frames.Count
    $r.AvgFrameMs=$avgFrame
    $r.MedianFrameMs=Pct $frames 50
    $r.AvgFps=if($avgFrame -gt 0){1000/$avgFrame}else{$null}
    $r.Low1=if($worstAvg -gt 0){1000/$worstAvg}else{$null}
    $maxFrame=($frames|Measure-Object -Maximum).Maximum
    $r.MaxFrameMs=$maxFrame
    $r.MinFps=if($maxFrame -gt 0){1000/$maxFrame}else{$null}
    $r.P95FrameMs=Pct $frames 95
    $r.AvgGpuBusyPct=Avg $gpuRatios
    $r.AvgGpuBusyMs=Avg $gpuMs
    $r.AvgCpuBusyMs=Avg $cpuMs
    return [pscustomobject]$r
}
function Classify($pm,$samples,[int]$ElapsedSeconds){
    $maxCores=@($samples|ForEach-Object{$_.MaxCore}|Where-Object{$null -ne $_})
    $gpuWin=@($samples|ForEach-Object{$_.GpuEngine}|Where-Object{$null -ne $_})
    $core95=Pct $maxCores 95
    $coreAvg=Avg $maxCores
    $gpuWinAvg=Avg $gpuWin
    $gpuSignal=if($pm.Available -and $null -ne $pm.AvgGpuBusyPct){[double]$pm.AvgGpuBusyPct}else{$gpuWinAvg}

    $result='SIN LIMITACION CLARA'
    $confidence='BAJA'
    $reason='CPU and GPU do not show a clear enough saturation during the test.'

    if($ElapsedSeconds -lt 20 -or ($pm.Available -and $pm.Frames -lt 120)){
        return [pscustomobject]@{Result='PRUEBA NO CONCLUYENTE';Confidence='BAJA';Reason='The sample was too short or had too few valid frames.';Core95=$core95;CoreAvg=$coreAvg;GpuSignal=$gpuSignal;GpuWinAvg=$gpuWinAvg}
    }

    if($null -ne $gpuSignal -and $null -ne $core95){
        if($gpuSignal -ge 92 -and $core95 -ge 92){
            $result='MIXTO / EQUILIBRADO';$confidence='MEDIA'
            $reason='The GPU worked near its limit while some CPU threads were also heavily loaded.'
        }elseif($gpuSignal -ge 92 -and $core95 -lt 88){
            $result='GPU';$confidence=if($gpuSignal -ge 96 -and $core95 -lt 82){'ALTA'}else{'MEDIA'}
            $reason='The GPU stayed busy most of the time while CPU threads kept headroom.'
        }elseif($core95 -ge 92 -and $gpuSignal -lt 80){
            $result='CPU';$confidence=if($core95 -ge 97 -and $gpuSignal -lt 70){'ALTA'}else{'MEDIA'}
            $reason='One or more CPU threads were heavily loaded while the GPU still had headroom.'
        }elseif($gpuSignal -ge 85){
            $result='GPU';$confidence='MEDIA'
            $reason='The GPU had a high load during a large part of the test.'
        }elseif($core95 -ge 90){
            $result='CPU';$confidence='MEDIA'
            $reason='Per-thread CPU load was high while the GPU was not fully utilized.'
        }else{
            $result='SIN LIMITACION CLARA';$confidence='MEDIA'
            $reason='Neither the GPU nor CPU threads stayed clearly near their limit.'
        }
    }elseif($null -ne $gpuSignal){
        if($gpuSignal -ge 93){$result='GPU';$confidence='MEDIA';$reason='The GPU was very busy, but reliable per-thread CPU data was missing.'}
        else{$result='SIN LIMITACION CLARA';$confidence='BAJA';$reason='Reliable per-thread CPU data was missing.'}
    }elseif($null -ne $core95){
        if($core95 -ge 95){$result='CPU';$confidence='BAJA';$reason='CPU threads were heavily loaded, but there was not enough GPU telemetry.'}
        else{$result='SIN LIMITACION CLARA';$confidence='BAJA';$reason='There was not enough GPU telemetry.'}
    }else{
        $result='PRUEBA NO CONCLUYENTE';$confidence='BAJA';$reason='Not enough CPU/GPU metrics could be collected.'
    }
    return [pscustomobject]@{Result=$result;Confidence=$confidence;Reason=$reason;Core95=$core95;CoreAvg=$coreAvg;GpuSignal=$gpuSignal;GpuWinAvg=$gpuWinAvg}
}
function Recommendations([string]$Result){
    switch($Result){
        'CPU' {
            return @(
                'Close heavy background applications.',
                'Check RAM stability/speed and temperatures.',
                'Try WinTool''s Gaming Profile.',
                'Lowering graphics does not always help much when the main limit is CPU.'
            )
        }
        'GPU' {
            return @(
                'Lower resolution or the heaviest graphics settings first.',
                'Use in-game upscaling if available.',
                'Check GPU temperatures and clock speed.',
                'A GPU near 100% utilization can be completely normal.'
            )
        }
        'MIXTO / EQUILIBRADO' {
            return @(
                'The system is heavily using both CPU and GPU.',
                'Find a balance between graphics quality and your target FPS.',
                'Avoid heavy background processes.'
            )
        }
        default {
            return @(
                'Check the FPS cap, VSync and game settings.',
                'Repeat the test in a more representative match or area.',
                'Check RAM, disk, temperatures and background processes if there are stutters.'
            )
        }
    }
}

function FriendlyBottleneckText($s){
    switch([string]$s.Result){
        'CPU' {return 'The CPU was the main limitation during this test.'}
        'GPU' {return 'The GPU was the main limitation during this test.'}
        'MIXTO / EQUILIBRADO' {return 'CPU and GPU were both heavily loaded at the same time; the system was fairly balanced.'}
        'PRUEBA NO CONCLUYENTE' {return 'There was not enough data to determine a limitation reliably.'}
        default {return 'No clear bottleneck was detected. CPU and GPU still had headroom.'}
    }
}
function DetectFpsCap($pm){
 $r=[ordered]@{Detected=$false;Cap=$null;Text='NOT DETECTED'}
 if(-not $pm.Available -or $null -eq $pm.AvgFps -or $null -eq $pm.AvgFrameMs){return [pscustomobject]$r}
 $avg=[double]$pm.AvgFps
 $typical=if($null -ne $pm.MedianFrameMs -and [double]$pm.MedianFrameMs -gt 0){1000/[double]$pm.MedianFrameMs}else{$avg}
 $caps=@(30,50,60,72,75,90,100,120,144,165,180,200,240,360,480)
 $nearest=$caps|Sort-Object {[math]::Abs($_-$typical)}|Select-Object -First 1
 if($nearest){
   $typicalClose=($typical -ge ($nearest*0.985) -and $typical -le ($nearest*1.015))
   $avgReasonable=($avg -ge ($nearest*0.90) -and $avg -le ($nearest*1.015))
   if($typicalClose -and $avgReasonable){
     $r.Detected=$true;$r.Cap=$nearest
     $r.Text=("POSSIBLE FPS LIMIT / VSYNC NEAR {0} FPS" -f $nearest)
   }
 }
 [pscustomobject]$r
}
function FpsCapDisplay($s){
    try{
        $t=[string]$s.FpsCapText
        if(-not [string]::IsNullOrWhiteSpace($t)){return $t.Trim()}
        if($s.FpsCapDetected -and $null -ne $s.FpsCap){return ('POSSIBLE FPS LIMIT / VSYNC NEAR '+$s.FpsCap+' FPS')}
    }catch{}
    return 'NOT DETECTED'
}
function ShowSimpleResult($s){
    WAHeader
    Write-Host 'TEST RESULT'
    Write-Host ''
    Write-Host ('Game.................. '+$s.Game)
    Write-Host ('Duration.............. '+$s.Duration+' s')
    Write-Host ''
    Write-Host 'PERFORMANCE'
    Write-Host ('Average FPS........... '+$(if($null -ne $s.AvgFps){(F1 $s.AvgFps)+' FPS'}else{'NOT AVAILABLE'}))
    Write-Host ('1% Low................ '+$(if($null -ne $s.Low1){(F1 $s.Low1)+' FPS'}else{'NOT AVAILABLE'}))
    Write-Host ('Minimum FPS detected.. '+$(if($null -ne $s.MinFps){(F1 $s.MinFps)+' FPS'}else{'NOT AVAILABLE'}))
    Write-Host ('Smoothness............ '+(ENState $s.Fluidity))
    Write-Host ('FPS limit.............. '+(FpsCapDisplay $s))
    Write-Host ''
    Write-Host 'SYSTEM USAGE'
    Write-Host ('CPU................... '+$(if($null -ne $s.ProcCpuAvg){(F1 $s.ProcCpuAvg)+'%'}else{'NOT AVAILABLE'}))
    Write-Host ('Most loaded CPU core.. '+$(if($null -ne $s.Core95){(F1 $s.Core95)+'%'}else{'NOT AVAILABLE'}))
    Write-Host ('GPU................... '+$(if($null -ne $s.GpuSimple){(F1 $s.GpuSimple)+'%'}else{'NOT AVAILABLE'}))
    Write-Host ('RAM................... '+$(if($null -ne $s.RamPctAvg){(F1 $s.RamPctAvg)+'%'}else{'NOT AVAILABLE'}))
    Write-Host ('Graphics memory....... '+(ENState $s.GpuMemoryStatus))
    Write-Host ''
    Write-Host 'BOTTLENECK'
    if($s.FpsCapDetected){
        Write-Host ('Possible '+$s.FpsCap+' FPS limit / VSync detected.')
        Write-Host 'There is not enough evidence to confirm a bottleneck from this test alone.'
        Write-Host 'Confidence............. LOW / FPS CAP DETECTED'
    }else{
        Write-Host (FriendlyBottleneckText $s)
        Write-Host ('Confidence............. '+(ENConfidence $s.Confidence))
    }
}
function ShowAdvanced($s){
    WAHeader
    Write-Host 'ADVANCED DATA'
    Write-Host ''
    Write-Host 'FRAMES'
    Write-Host ('Average FPS........... '+(ValText $s.AvgFps ' FPS'))
    Write-Host ('1% Low................ '+(ValText $s.Low1 ' FPS'))
    Write-Host ('Minimum FPS detected.. '+(ValText $s.MinFps ' FPS'))
    Write-Host ('Average frametime..... '+(ValText $s.AvgFrameMs ' ms'))
    Write-Host ('Median frametime...... '+(ValText $s.MedianFrameMs ' ms'))
    Write-Host ('Frametime P95......... '+(ValText $s.P95FrameMs ' ms'))
    Write-Host ('Worst frametime....... '+(ValText $s.MaxFrameMs ' ms'))
    Write-Host ('Frames analyzed....... '+$s.Frames)
    Write-Host ''
    Write-Host 'CPU'
    Write-Host ('Game CPU usage........ '+(ValText $s.ProcCpuAvg '%'))
    Write-Host ('Total CPU usage....... '+(ValText $s.CpuTotalAvg '%'))
    Write-Host ('Most loaded CPU core.. '+(ValText $s.Core95 '% (P95)'))
    Write-Host ('Estimated background load.. '+(ValText $s.BackgroundCpuAvg '%'))
    Write-Host ''
    Write-Host 'GPU'
    Write-Host ('Current GPU load...... '+(ValText $s.GpuBusyPct '%'))
    Write-Host ('Windows GPU usage..... '+(ValText $s.GpuWindowsAvg '%'))
    Write-Host ('Dedicated memory...... '+(ValText $s.DedicatedMaxMB ' MB used'))
    Write-Host ('Shared memory......... '+(ValText $s.SharedMaxMB ' MB used'))
    Write-Host ''
    Write-Host 'MEMORY AND DISK'
    Write-Host ('System RAM............ '+(ValText $s.RamPctAvg '%'))
    Write-Host ('Game RAM.............. '+(ValText $s.GameRamAvgMB ' MB'))
    Write-Host ('Disk activity......... '+(ValText $s.DiskPctAvg '%'))
    Write-Host ''
    Write-Host 'NOTES'
    Write-Host '- P95 represents a frequently high level without depending on a single isolated spike.'
    Write-Host '- Minimum FPS may represent a stutter, a temporary load or a scene change.'
    Write-Host '- Graphics memory shows observed usage; not all drivers expose a reliable total limit.'
    Write-Host '- GPU Busy is shown as Current GPU load on this screen.'
    Write-Host ''
    Read-Host 'Press ENTER to go back' | Out-Null
}
function SlowdownPrimary($s){
    if($s.FpsCapDetected){return 'POSSIBLE FPS LIMIT / VSYNC'}
    if($s.Result -eq 'CPU'){return 'CPU LIMITATION'}
    if($s.Result -eq 'GPU'){return 'GPU LIMITATION'}
    if($s.Result -eq 'MIXTO / EQUILIBRADO'){return 'CPU AND GPU HEAVILY LOADED'}
    if($null -ne $s.RamPctAvg -and [double]$s.RamPctAvg -ge 90){return 'RAM PRESSURE'}
    if($null -ne $s.DiskPctAvg -and [double]$s.DiskPctAvg -ge 80 -and $s.Fluidity -eq 'REVISAR'){return 'DISK ACTIVITY / RESOURCE LOADING'}
    if($s.Fluidity -eq 'REVISAR'){return 'STUTTERS OR OCCASIONAL DROPS'}
    return 'NO CLEAR MAIN ISSUE DETECTED'
}
function ShowSlowdown($s){
    while($true){
        WAHeader
        Write-Host 'WHAT IS SLOWING DOWN MY GAME?'
        Write-Host ''
        Write-Host 'MAIN ISSUE'
        Write-Host (SlowdownPrimary $s)
        Write-Host ''
        if($s.Fluidity -eq 'REVISAR'){
            Write-Host 'The test found significant drops compared with normal performance.'
            if($s.Result -eq 'SIN LIMITACION CLARA'){
                Write-Host 'They do not appear to be caused by a constant CPU or GPU bottleneck.'
            }
        }elseif($s.Result -eq 'SIN LIMITACION CLARA'){
            Write-Host 'CPU and GPU kept headroom and overall smoothness shows no major warning.'
        }else{
            Write-Host $s.Reason
        }
        Write-Host ''
        Write-Host ('CPU................... '+(ENState (StatusFromPct $s.Core95 85 95)))
        Write-Host ('GPU................... '+(ENState (StatusFromPct $s.GpuSimple 85 95)))
        Write-Host ('RAM................... '+(ENState (StatusFromPct $s.RamPctAvg 80 90)))
        Write-Host ('Disk................... '+(ENState (StatusFromPct $s.DiskPctAvg 65 85)))
        Write-Host ('Background............. '+(ENState (StatusFromPct $s.BackgroundCpuAvg 20 35)))
        Write-Host ('FPS stability......... '+(ENState $s.Fluidity))
        Write-Host ''
        Write-Host 'RECOMMENDATIONS'
        if($s.GamingProfileActive){
            Write-Host '[OK] WinTool Gaming Profile: ACTIVE.'
        }else{
            Write-Host '[RECOMMENDED] WinTool Gaming Profile: NOT ACTIVE.'
            Write-Host 'It can reduce visual effects, background recording and use Windows Ultimate Performance.'
        }
        if($s.FpsCapDetected){
            Write-Host ('[INFO] The test stayed near a common '+$s.FpsCap+' FPS.')
            Write-Host '[INFO] To study the raw bottleneck, repeat the test without VSync/FPS cap if you want and the game allows it.'
        }elseif($s.Result -eq 'CPU'){
            Write-Host '[CHECK] Close heavy processes and check RAM/temperatures if FPS remains limited.'
        }elseif($s.Result -eq 'GPU'){
            Write-Host '[CHECK] Lower resolution or the heaviest graphics settings if you want more FPS.'
        }elseif($s.Fluidity -eq 'REVISAR'){
            Write-Host '[CHECK] Stutters were detected. Repeat the test while avoiding menus/loading to confirm whether they are frequent.'
            if($null -ne $s.DiskPctAvg -and [double]$s.DiskPctAvg -ge 65){Write-Host '[CHECK] Disk activity was high during part of the measurement.'}
        }else{
            Write-Host '[OK] No single major cause appears in this test.'
        }
        if($null -ne $s.BackgroundCpuAvg -and [double]$s.BackgroundCpuAvg -ge 20){
            Write-Host '[INFO] There was CPU load outside the game; closing apps may improve stability.'
        }
        Write-Host ''
        Write-Host ('Analysis confidence: '+(ENConfidence $s.Confidence))
        Write-Host ''
        if(-not $s.GamingProfileActive -and $ToolsDir -and $BackupsDir -and (Test-Path (Join-Path $ToolsDir 'GamingProfileV54.ps1'))){
            Write-Host '[1] Enable WinTool Gaming Profile'
            Write-Host '[2] Back to result'
            $op=(Read-Host 'Choose').Trim()
            if($op -eq '1'){
                $ok=(Read-Host 'Apply Gaming Profile now? [Y/N]').Trim()
                if($ok -match '^[Yy]$'){
                    & (Join-Path $ToolsDir 'GamingProfileV54.ps1') -Mode Apply -BackupDir $BackupsDir
                    $s.GamingProfileActive=(GamingProfileActive)
                    Write-Host ''
                    Read-Host 'Press ENTER to continue' | Out-Null
                }
                continue
            }
            if($op -eq '2'){return}
        }else{
            Read-Host 'Press ENTER to go back to the result' | Out-Null
            return
        }
    }
}
function OptimizeGame($s){
 while($true){
   WAHeader
   Write-Host 'OPTIMIZE GAME'
   Write-Host ''
   $pidToUse=0
   try{$pidToUse=[int]$s.PID}catch{}
   if($pidToUse -le 0){
     Write-Host '[CHECK] This test does not have a valid PID.'
     Read-Host 'Press ENTER to go back'|Out-Null;return
   }
   $proc=Get-Process -Id $pidToUse -ErrorAction SilentlyContinue
   if(-not $proc){
     Write-Host '[INFO] The game from this test is no longer running.'
     Write-Host 'Open the game and run a new test to optimize that process.'
     Read-Host 'Press ENTER to go back'|Out-Null;return
   }
   $optimizer=Join-Path $ToolsDir 'GameOptimizerV58.ps1'
   if(-not(Test-Path -LiteralPath $optimizer)){
     Write-Host '[CHECK] The game optimization component is missing.'
     Read-Host 'Press ENTER to go back'|Out-Null;return
   }
   & $optimizer -Mode Inspect -TargetPid $pidToUse -StateDir $ConfigDir
   Write-Host ''
   Write-Host '[1] APPLY TEMPORARY OPTIMIZATION'
   Write-Host '[2] RESTORE WINTOOL CHANGES'
   Write-Host '[3] BACK'
   $o=(Read-Host 'Choose').Trim()
   if($o -eq '1'){
     Write-Host ''
     Write-Host '[INFO] WinTool only raises priorities below ABOVE NORMAL.'
     Write-Host '[INFO] If you already use Above Normal, High or Realtime, it will NOT lower or replace it.'
     Write-Host '[INFO] It does not change CPU affinity, GPU Priority, HPET, BCD or Realtime.'
     $c=(Read-Host 'Apply? [Y/N]').Trim()
     if($c -match '^[Yy]$'){
       & $optimizer -Mode Apply -TargetPid $pidToUse -StateDir $ConfigDir
       Write-Host ''
       Write-Host '[OK] Optimization applied to the current process.'
       Write-Host '[INFO] Use RESTORE before closing WinAnalyzer if you want to return to the original state.'
       Read-Host 'Press ENTER to continue'|Out-Null
     }
     continue
   }
   if($o -eq '2'){
     & $optimizer -Mode Restore -TargetPid $pidToUse -StateDir $ConfigDir
     Read-Host 'Press ENTER to continue'|Out-Null
     continue
   }
   if($o -eq '3'){return}
 }
}
function PostResultMenu($s){
    while($true){
        ShowSimpleResult $s
        Write-Host ''
        Write-Host '[1] ADVANCED DATA'
        Write-Host '[2] WHAT IS SLOWING DOWN MY GAME?'
        Write-Host '[3] OPTIMIZE GAME'
        Write-Host '[4] FINISH'
        $op=(Read-Host 'Choose').Trim()
        if($op -eq '1'){ShowAdvanced $s;continue}
        if($op -eq '2'){ShowSlowdown $s;continue}
        if($op -eq '3'){OptimizeGame $s;continue}
        if($op -eq '4'){return}
        Write-Host '[CHECK] Choose 1, 2, 3 or 4.'
        Start-Sleep -Milliseconds 600
    }
}
function PersistResult($summary,[string]$txtPath,[string]$jsonPath,[string]$lastPath){
    $lines=New-Object System.Collections.Generic.List[string]
    $lines.Add('WinAnalyzer V1.0 - RESULT')
    $lines.Add('')
    $lines.Add(('Game: '+$summary.Game))
    $lines.Add(('Date: '+$summary.Date))
    $lines.Add(('Duration: '+$summary.Duration+' s'))
    $lines.Add('')
    $lines.Add('SIMPLE RESULT')
    $lines.Add(('Average FPS: '+(ValText $summary.AvgFps ' FPS')))
    $lines.Add(('1% Low: '+(ValText $summary.Low1 ' FPS')))
    $lines.Add(('Minimum FPS detected: '+(ValText $summary.MinFps ' FPS')))
    $lines.Add(('Smoothness: '+(ENState $summary.Fluidity)))
    $lines.Add(('FPS cap/VSync: '+(FpsCapDisplay $summary)))
    $lines.Add(('Game CPU: '+(ValText $summary.ProcCpuAvg '%')))
    $lines.Add(('Most loaded CPU core: '+(ValText $summary.Core95 '%')))
    $lines.Add(('GPU: '+(ValText $summary.GpuSimple '%')))
    $lines.Add(('RAM: '+(ValText $summary.RamPctAvg '%')))
    $lines.Add(('Bottleneck: '+(ENResult $summary.Result)+' | Confidence '+(ENConfidence $summary.Confidence)))
    $lines.Add(('Reason: '+$summary.Reason))
    $lines.Add('')
    $lines.Add('ADVANCED DATA')
    $lines.Add(('Frames: '+$summary.Frames))
    $lines.Add(('Average frametime: '+(ValText $summary.AvgFrameMs ' ms')))
    $lines.Add(('Frametime P95: '+(ValText $summary.P95FrameMs ' ms')))
    $lines.Add(('Worst frametime: '+(ValText $summary.MaxFrameMs ' ms')))
    $lines.Add(('GPU Busy: '+(ValText $summary.GpuBusyPct '%')))
    $lines.Add(('GPU Windows: '+(ValText $summary.GpuWindowsAvg '%')))
    $lines.Add(('Total CPU usage: '+(ValText $summary.CpuTotalAvg '%')))
    $lines.Add(('Estimated additional CPU load: '+(ValText $summary.BackgroundCpuAvg '%')))
    $lines.Add(('Average disk: '+(ValText $summary.DiskPctAvg '%')))
    $lines.Add(('Game RAM: '+(ValText $summary.GameRamAvgMB ' MB')))
    $lines.Add(('Dedicated GPU memory: '+(ValText $summary.DedicatedMaxMB ' MB')))
    $lines.Add(('Shared GPU memory: '+(ValText $summary.SharedMaxMB ' MB')))
    $lines.Add('')
    $lines.Add('NOTES')
    $lines.Add('- This result describes this test, not absolute CPU/GPU compatibility.')
    $lines.Add('- Minimum FPS may represent a real stutter, loading event or scene change.')
    $lines.Add('- Graphics memory is reported without declaring saturation when the driver does not expose a reliable total.')
    [IO.File]::WriteAllLines($txtPath,$lines,(New-Object Text.UTF8Encoding($false)))
    $summary|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $jsonPath -Encoding UTF8
    $summary|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $lastPath -Encoding UTF8
}
Ensure $ReportsRoot
Ensure $ConfigDir
$waRoot=Join-Path $ReportsRoot 'WinAnalyzer'
$rawRoot=Join-Path $waRoot 'RAW'
$testsRoot=Join-Path $waRoot 'Pruebas'
Ensure $waRoot;Ensure $rawRoot;Ensure $testsRoot
$lastFile=Join-Path $ConfigDir 'WinAnalyzer_Last.json'

if($Mode -eq 'Component'){
    $v=VerifyPresentMon
    Write-Host 'PRESENTMON - WinAnalyzer COMPONENT'
    Write-Host ''
    Write-Host ('Status............... '+$(if(-not $v.Exists){'NOT FOUND'}elseif($v.HashOk){'INTEGRATED AND VERIFIED'}else{'DIFFERENT FILE / NOT VERIFIED'}))
    Write-Host ('Expected version..... '+$ExpectedVersion)
    if($v.Version){Write-Host ('File version.......... '+$v.Version)}
    if($v.Exists){Write-Host ('SHA-256 verified..... '+$(if($v.HashOk){'YES'}else{'NO'}))}
    Write-Host ('Windows signature.... '+(ENSignature $v.Signature))
    Write-Host ''
    Write-Host 'If the component is missing, WinAnalyzer can run a basic test without FPS/frametimes.'
    exit 0
}

if($Mode -eq 'Info'){
    Write-Host 'HOW WinAnalyzer WORKS'
    Write-Host ''
    Write-Host '1. Choose a game that is already running.'
    Write-Host '2. PresentMon records frames, frametime and GPU Busy.'
    Write-Host '3. WinAnalyzer measures per-core CPU load, GPU, RAM, graphics memory and disk activity.'
    Write-Host '4. WinAnalyzer combines the measurements and classifies the test as:'
    Write-Host '   CPU / GPU / MIXED / NO CLEAR LIMITATION / INCONCLUSIVE.'
    Write-Host '5. It always shows a confidence level: HIGH, MEDIUM or LOW.'
    Write-Host ''
    Write-Host 'It does not use a CPU/GPU database or invent a bottleneck percentage.'
    Write-Host 'A CPU/GPU result only describes the game, scene and settings used during that test.'
    Write-Host ''
    Write-Host 'VRAM / graphics memory:'
    Write-Host 'Windows may expose dedicated and shared memory used by the process.'
    Write-Host 'Shared memory use is normal on an iGPU. WinAnalyzer V1.0 does not declare VRAM exhausted'
    Write-Host 'because some drivers do not provide a reliable total video-memory value.'
    exit 0
}

if($Mode -eq 'Last'){
    if(-not(Test-Path $lastFile)){WAHeader;Write-Host '[INFO] There is no saved test yet.';exit 0}
    try{$s=Get-Content $lastFile -Raw|ConvertFrom-Json}catch{WAHeader;Write-Host '[ERROR] The last test could not be read.';exit 2}
    if($null -eq $s.Fluidity){
        $fl='NOT AVAILABLE'
        if($null -ne $s.AvgFps -and $null -ne $s.Low1 -and [double]$s.AvgFps -gt 0){
            $rr=[double]$s.Low1/[double]$s.AvgFps
            if($rr -ge .7){$fl='BUENA'}elseif($rr -ge .5){$fl='ACEPTABLE'}else{$fl='REVISAR'}
        }
        $s|Add-Member -NotePropertyName Fluidity -NotePropertyValue $fl -Force
    }
    if($null -eq $s.GpuSimple){$s|Add-Member -NotePropertyName GpuSimple -NotePropertyValue $(if($null -ne $s.GpuBusyPct){$s.GpuBusyPct}else{$s.GpuWindowsAvg}) -Force}
    if($null -eq $s.GpuMemoryStatus){$s|Add-Member -NotePropertyName GpuMemoryStatus -NotePropertyValue 'SIN ALERTA' -Force}
    if($null -eq $s.GamingProfileActive){$s|Add-Member -NotePropertyName GamingProfileActive -NotePropertyValue (GamingProfileActive) -Force}
    if($null -eq $s.FpsCapDetected){$s|Add-Member -NotePropertyName FpsCapDetected -NotePropertyValue $false -Force}
    if($null -eq $s.FpsCap){$s|Add-Member -NotePropertyName FpsCap -NotePropertyValue $null -Force}
    if($null -eq $s.FpsCapText -or [string]::IsNullOrWhiteSpace([string]$s.FpsCapText)){
        $s|Add-Member -NotePropertyName FpsCapText -NotePropertyValue 'NOT AVAILABLE IN THIS TEST' -Force
    }
    if($null -eq $s.MedianFrameMs){$s|Add-Member -NotePropertyName MedianFrameMs -NotePropertyValue $null -Force}
    PostResultMenu $s
    exit 0
}

if($Mode -eq 'History'){
    $files=@(Get-ChildItem -LiteralPath $testsRoot -Filter '*.json' -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending|Select-Object -First 12)
    if($files.Count -eq 0){Write-Host '[INFO] There is no WinAnalyzer history yet.';exit 0}
    Write-Host 'WinAnalyzer HISTORY'
    Write-Host ''
    foreach($f in $files){
        try{
            $s=Get-Content $f.FullName -Raw|ConvertFrom-Json
            $fps=if($null -ne $s.AvgFps){F1 $s.AvgFps}else{'N/D'}
            $low=if($null -ne $s.Low1){F1 $s.Low1}else{'N/D'}
            Write-Host ('{0} | {1} | {2} ({3}) | FPS {4} | 1% {5}' -f $s.Date,$s.Game,(ENResult $s.Result),(ENConfidence $s.Confidence),$fps,$low)
        }catch{}
    }
    Write-Host ''
    Write-Host ('Test folder: '+$testsRoot)
    exit 0
}

# ANALYZE
WAHeader
Write-Host 'ANALYZE MY GAME'
Write-Host 'FPS, smoothness and bottleneck test'
Write-Host ''
Write-Host 'BEFORE YOU START'
Write-Host '- Close as many applications as you do not need.'
Write-Host '- Leave the launcher/Discord open only if you actually use them while gaming.'
Write-Host '- Open the game and enter a representative match or area.'
Write-Host '- Avoid menus, loading screens and standing still for the entire test.'
Write-Host '- WinAnalyzer will NOT close programs automatically.'
Write-Host '- Play normally during the test so the result is representative.'
Write-Host ''
$ready=(Read-Host 'When the game is ready, type READY. Type C to cancel').Trim()
if($ready -match '^[Cc]$'){exit 0}
if($ready.ToUpperInvariant() -ne 'READY'){Write-Host '[INFO] Test cancelled.';exit 0}

$target=ReadTarget
if($null -eq $target){Write-Host '[INFO] Test cancelled.';exit 0}
$duration=ReadDuration
$targetPid=[int]$target.PID
try{$targetProc=Get-Process -Id $targetPid -ErrorAction Stop}catch{Write-Host '[ERROR] The process is no longer running.';exit 2}

$pmVerify=VerifyPresentMon
$usePm=$pmVerify.Exists -and $pmVerify.HashOk
if(-not $usePm){
    Write-Host ''
    if(-not $pmVerify.Exists){Write-Host '[INFO] Bundled PresentMon is not available.'}
    else{Write-Host '[CHECK] PresentMon does not match WinTool''s verified component.'}
    Write-Host 'The test can continue in BASIC mode without PresentMon FPS/1% Low/GPU Busy.'
    $ans=(Read-Host 'Continue in basic mode? [Y/N]').Trim()
    if($ans -notmatch '^[Yy]$'){exit 0}
}

Write-Host ''
Write-Host ('Selected game: '+$target.Friendly+' ('+$target.Name+'.exe)')
Write-Host ('Duration: '+$duration+' seconds')
Write-Host ''
Write-Host 'You have 5 seconds to return to the game...'
for($i=5;$i -ge 1;$i--){Write-Host ($i.ToString()+'...');Start-Sleep -Seconds 1}

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$safeName=($target.Name -replace '[^A-Za-z0-9._-]','_')
$csv=Join-Path $rawRoot ($stamp+'_'+$safeName+'.csv')
$txt=Join-Path $testsRoot ($stamp+'_'+$safeName+'.txt')
$json=Join-Path $testsRoot ($stamp+'_'+$safeName+'.json')
$session='WinAnalyzer_'+$targetPid+'_'+(Get-Random -Minimum 1000 -Maximum 9999)

$pmProc=$null
if($usePm){
    $arg='--process_id {0} --output_file "{1}" --timed {2} --terminate_after_timed --terminate_on_proc_exit --no_console_stats --session_name "{3}" --stop_existing_session' -f $targetPid,$csv,$duration,$session
    try{$pmProc=Start-Process -FilePath $PresentMonPath -ArgumentList $arg -WindowStyle Hidden -PassThru -ErrorAction Stop}catch{
        Write-Host '[INFO] PresentMon could not start. Continuing with basic measurement.'
        $usePm=$false
    }
}

$samples=New-Object System.Collections.Generic.List[object]
$prevCpu=[double]$targetProc.TotalProcessorTime.TotalSeconds
$prevTime=Get-Date
$sw=[Diagnostics.Stopwatch]::StartNew()
$lastShown=-1
while($sw.Elapsed.TotalSeconds -lt $duration){
    if(-not(Get-Process -Id $targetPid -ErrorAction SilentlyContinue)){break}
    Start-Sleep -Milliseconds 950
    $s=SnapshotSystem $targetPid $prevCpu $prevTime
    if($null -eq $s){break}
    $samples.Add($s)
    $prevCpu=$s.CpuSec;$prevTime=$s.Time
    $pct=[math]::Min(100,[int](($sw.Elapsed.TotalSeconds/$duration)*100))
    $bucket=[math]::Floor($pct/10)
    if($bucket -ne $lastShown){
        $lastShown=$bucket
        $fill=[math]::Floor($pct/5)
        $bar=('='*$fill)+('.'*(20-$fill))
        Write-Host ('[{0}] {1,3}%  Analyzing {2}' -f $bar,$pct,$target.Friendly)
    }
}
$sw.Stop()
$elapsed=[int][math]::Round($sw.Elapsed.TotalSeconds)

if($pmProc){
    try{
        if(-not $pmProc.HasExited){$pmProc.WaitForExit(12000)}
    }catch{}
    if(-not $pmProc.HasExited){
        try{
            & $PresentMonPath --session_name $session --terminate_existing_session --no_csv --no_console_stats | Out-Null
        }catch{}
        try{Stop-Process -Id $pmProc.Id -Force -ErrorAction SilentlyContinue}catch{}
    }
}
Start-Sleep -Milliseconds 500

$pm=if($usePm){ParsePresentMon $csv $targetPid}else{[pscustomobject]@{Available=$false;Frames=0;AvgFps=$null;Low1=$null;MinFps=$null;AvgFrameMs=$null;MedianFrameMs=$null;P95FrameMs=$null;MaxFrameMs=$null;AvgGpuBusyPct=$null;AvgGpuBusyMs=$null;AvgCpuBusyMs=$null}}
$class=Classify $pm $samples $elapsed

$procCpuAvg=Avg @($samples|ForEach-Object{$_.ProcCpu})
$cpuTotalAvg=Avg @($samples|ForEach-Object{$_.CpuTotal})
$ramPctAvg=Avg @($samples|ForEach-Object{$_.RamPct})
$diskPctAvg=Avg @($samples|ForEach-Object{$_.DiskPct})
$gameRamAvg=Avg @($samples|ForEach-Object{$_.GameRam})
$dedMax=(@($samples|ForEach-Object{$_.Dedicated}|Where-Object{$null -ne $_})|Measure-Object -Maximum).Maximum
$shrMax=(@($samples|ForEach-Object{$_.Shared}|Where-Object{$null -ne $_})|Measure-Object -Maximum).Maximum
$backgroundCpu=$null
if($null -ne $cpuTotalAvg -and $null -ne $procCpuAvg){$backgroundCpu=[math]::Max(0,[double]$cpuTotalAvg-[double]$procCpuAvg)}
$gpuSimple=if($null -ne $pm.AvgGpuBusyPct){$pm.AvgGpuBusyPct}else{$class.GpuWinAvg}
$gpuMemStatus=if($null -ne $dedMax -or $null -ne $shrMax){'SIN ALERTA'}else{'NOT AVAILABLE'}
$fluidity=Fluidity $pm
$capInfo=DetectFpsCap $pm

$summary=[pscustomobject]@{
    Version='1.0'
    WinToolVersion='1.1.0'
    Date=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Game=$target.Friendly
    Process=$target.Name
    PID=$targetPid
    Duration=$elapsed
    PresentMonUsed=[bool]$pm.Available
    Frames=$pm.Frames
    AvgFps=$pm.AvgFps
    Low1=$pm.Low1
    MinFps=$pm.MinFps
    AvgFrameMs=$pm.AvgFrameMs
    MedianFrameMs=$pm.MedianFrameMs
    P95FrameMs=$pm.P95FrameMs
    MaxFrameMs=$pm.MaxFrameMs
    GpuBusyPct=$pm.AvgGpuBusyPct
    GpuWindowsAvg=$class.GpuWinAvg
    GpuSimple=$gpuSimple
    ProcCpuAvg=$procCpuAvg
    CpuTotalAvg=$cpuTotalAvg
    BackgroundCpuAvg=$backgroundCpu
    Core95=$class.Core95
    CoreAvg=$class.CoreAvg
    RamPctAvg=$ramPctAvg
    DiskPctAvg=$diskPctAvg
    GameRamAvgMB=$(if($null -ne $gameRamAvg){Mb $gameRamAvg}else{$null})
    DedicatedMaxMB=$(if($null -ne $dedMax){Mb $dedMax}else{$null})
    SharedMaxMB=$(if($null -ne $shrMax){Mb $shrMax}else{$null})
    GpuMemoryStatus=$gpuMemStatus
    Fluidity=$fluidity
    FpsCapDetected=[bool]$capInfo.Detected
    FpsCap=$capInfo.Cap
    FpsCapText=$(if([string]::IsNullOrWhiteSpace([string]$capInfo.Text)){'NOT DETECTED'}else{[string]$capInfo.Text})
    Result=$class.Result
    Confidence=$class.Confidence
    Reason=$class.Reason
    Recommendations=@(Recommendations $class.Result)
    GamingProfileActive=(GamingProfileActive)
    ReportPath=$txt
    RawCsv=$(if(Test-Path $csv){$csv}else{$null})
}
PersistResult $summary $txt $json $lastFile
PostResultMenu $summary
exit 0
