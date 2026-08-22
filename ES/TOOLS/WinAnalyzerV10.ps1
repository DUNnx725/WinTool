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
    if($null -eq $v){return 'NO DISPONIBLE'}
    return ((F1 $v)+$Suffix)
}
function Fluidity($pm){
    if(-not $pm.Available -or $null -eq $pm.AvgFps -or $null -eq $pm.Low1 -or $pm.AvgFps -le 0){return 'NO DISPONIBLE'}
    $ratio=[double]$pm.Low1/[double]$pm.AvgFps
    if($ratio -ge 0.70){return 'BUENA'}
    if($ratio -ge 0.50){return 'ACEPTABLE'}
    return 'REVISAR'
}
function GamingProfileActive {
    try{
        if(-not $BackupsDir){return $false}
        $marker=Join-Path $BackupsDir 'GamingV54\EstadoAnterior.json'
        return (Test-Path -LiteralPath $marker)
    }catch{return $false}
}
function StatusFromPct($v,[double]$Review,[double]$High){
    if($null -eq $v){return 'NO DISPONIBLE'}
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
    if($null -eq $v){return 'NO DISPONIBLE'}
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
        'javaw'='Minecraft / aplicacion Java'
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
    Write-Host 'BUSCANDO JUEGOS / APLICACIONES 3D...'
    Start-Sleep -Milliseconds 600
    $c=@(CandidateProcesses)
    if($c.Count -gt 0){
        Write-Host ''
        for($i=0;$i -lt $c.Count;$i++){
            $mark=if($c[$i].GpuActive){'GPU activa'}else{'ventana abierta'}
            Write-Host ('[{0}] {1}  ({2}.exe, PID {3}) - {4}' -f ($i+1),$c[$i].Friendly,$c[$i].Name,$c[$i].PID,$mark)
        }
        Write-Host '[M] Elegir manualmente por PID'
        Write-Host '[C] Cancelar'
        while($true){
            $sel=(Read-Host 'Selecciona el juego').Trim()
            if($sel -match '^[Cc]$'){return $null}
            if($sel -match '^[Mm]$'){
                $manual=Read-Host 'PID del juego'
                if($manual -match '^\d+$'){
                    try{
                        $p=Get-Process -Id ([int]$manual) -ErrorAction Stop
                        return [pscustomobject]@{PID=$p.Id;Name=$p.ProcessName;Friendly=(FriendlyName $p)}
                    }catch{Write-Host '[REVISAR] No existe ese PID.'}
                }
                continue
            }
            if($sel -match '^\d+$'){
                $n=[int]$sel
                if($n -ge 1 -and $n -le $c.Count){return $c[$n-1]}
            }
            Write-Host '[REVISAR] Opcion no valida.'
        }
    }
    Write-Host '[INFO] No se detectaron candidatos automaticamente.'
    $manual=Read-Host 'Escribe el PID del juego, o C para cancelar'
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
    Write-Host 'DURACION'
    Write-Host '[1] Rapida        30 segundos'
    Write-Host '[2] Recomendada   90 segundos'
    Write-Host '[3] Larga        180 segundos'
    while($true){
        $d=(Read-Host 'Elegir').Trim()
        if($d -eq '1'){return 30}
        if($d -eq '2'){return 90}
        if($d -eq '3'){return 180}
        Write-Host '[REVISAR] Elige 1, 2 o 3.'
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
    $reason='CPU y GPU no muestran una saturacion suficientemente clara durante la prueba.'

    if($ElapsedSeconds -lt 20 -or ($pm.Available -and $pm.Frames -lt 120)){
        return [pscustomobject]@{Result='PRUEBA NO CONCLUYENTE';Confidence='BAJA';Reason='La muestra fue demasiado corta o tuvo pocos frames validos.';Core95=$core95;CoreAvg=$coreAvg;GpuSignal=$gpuSignal;GpuWinAvg=$gpuWinAvg}
    }

    if($null -ne $gpuSignal -and $null -ne $core95){
        if($gpuSignal -ge 92 -and $core95 -ge 92){
            $result='MIXTO / EQUILIBRADO';$confidence='MEDIA'
            $reason='La GPU trabajo cerca de su limite y al mismo tiempo hubo hilos de CPU muy exigidos.'
        }elseif($gpuSignal -ge 92 -and $core95 -lt 88){
            $result='GPU';$confidence=if($gpuSignal -ge 96 -and $core95 -lt 82){'ALTA'}else{'MEDIA'}
            $reason='La GPU estuvo ocupada casi todo el tiempo mientras los hilos de CPU conservaron margen.'
        }elseif($core95 -ge 92 -and $gpuSignal -lt 80){
            $result='CPU';$confidence=if($core95 -ge 97 -and $gpuSignal -lt 70){'ALTA'}else{'MEDIA'}
            $reason='Uno o mas hilos de CPU estuvieron muy exigidos mientras la GPU tenia margen.'
        }elseif($gpuSignal -ge 85){
            $result='GPU';$confidence='MEDIA'
            $reason='La GPU tuvo una carga alta durante buena parte de la prueba.'
        }elseif($core95 -ge 90){
            $result='CPU';$confidence='MEDIA'
            $reason='La carga por hilo de CPU fue alta mientras la GPU no estuvo completamente ocupada.'
        }else{
            $result='SIN LIMITACION CLARA';$confidence='MEDIA'
            $reason='Ni la GPU ni los hilos de CPU permanecieron cerca de su limite de forma clara.'
        }
    }elseif($null -ne $gpuSignal){
        if($gpuSignal -ge 93){$result='GPU';$confidence='MEDIA';$reason='La GPU estuvo muy ocupada, pero faltaron datos fiables por hilo de CPU.'}
        else{$result='SIN LIMITACION CLARA';$confidence='BAJA';$reason='Faltaron datos fiables por hilo de CPU.'}
    }elseif($null -ne $core95){
        if($core95 -ge 95){$result='CPU';$confidence='BAJA';$reason='Los hilos de CPU estuvieron muy exigidos, pero no hubo telemetria GPU suficiente.'}
        else{$result='SIN LIMITACION CLARA';$confidence='BAJA';$reason='No hubo telemetria GPU suficiente.'}
    }else{
        $result='PRUEBA NO CONCLUYENTE';$confidence='BAJA';$reason='No se pudieron obtener suficientes metricas de CPU/GPU.'
    }
    return [pscustomobject]@{Result=$result;Confidence=$confidence;Reason=$reason;Core95=$core95;CoreAvg=$coreAvg;GpuSignal=$gpuSignal;GpuWinAvg=$gpuWinAvg}
}
function Recommendations([string]$Result){
    switch($Result){
        'CPU' {
            return @(
                'Cierra aplicaciones pesadas en segundo plano.',
                'Revisa estabilidad/velocidad de RAM y temperaturas.',
                'Prueba el Perfil Gaming de WinTool.',
                'Bajar graficos no siempre mejora mucho si el limite principal es CPU.'
            )
        }
        'GPU' {
            return @(
                'Baja primero resolucion o los ajustes graficos mas pesados.',
                'Usa escalado del juego si esta disponible.',
                'Comprueba temperaturas y frecuencia de la GPU.',
                'Una GPU cerca del 100% puede ser completamente normal.'
            )
        }
        'MIXTO / EQUILIBRADO' {
            return @(
                'El equipo esta usando fuertemente CPU y GPU.',
                'Busca el equilibrio entre calidad grafica y FPS objetivo.',
                'Evita procesos pesados en segundo plano.'
            )
        }
        default {
            return @(
                'Comprueba limite de FPS, VSync y configuracion del juego.',
                'Repite la prueba en una partida o zona mas representativa.',
                'Revisa RAM, disco, temperaturas y procesos en segundo plano si hay tirones.'
            )
        }
    }
}

function FriendlyBottleneckText($s){
    switch([string]$s.Result){
        'CPU' {return 'El procesador fue la limitacion principal durante esta prueba.'}
        'GPU' {return 'La GPU fue la limitacion principal durante esta prueba.'}
        'MIXTO / EQUILIBRADO' {return 'CPU y GPU trabajaron fuerte al mismo tiempo; el equipo estuvo bastante equilibrado.'}
        'PRUEBA NO CONCLUYENTE' {return 'No hubo suficientes datos para determinar una limitacion con seguridad.'}
        default {return 'No se detecto un cuello de botella claro. CPU y GPU todavia tuvieron margen.'}
    }
}
function DetectFpsCap($pm){
 $r=[ordered]@{Detected=$false;Cap=$null;Text='NO DETECTADO'}
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
     $r.Text=("POSIBLE LIMITE / VSYNC CERCA DE {0} FPS" -f $nearest)
   }
 }
 [pscustomobject]$r
}
function FpsCapDisplay($s){
    try{
        $t=[string]$s.FpsCapText
        if(-not [string]::IsNullOrWhiteSpace($t)){return $t.Trim()}
        if($s.FpsCapDetected -and $null -ne $s.FpsCap){return ('POSIBLE LIMITE / VSYNC CERCA DE '+$s.FpsCap+' FPS')}
    }catch{}
    return 'NO DETECTADO'
}
function ShowSimpleResult($s){
    WAHeader
    Write-Host 'RESULTADO DE LA PRUEBA'
    Write-Host ''
    Write-Host ('Juego................ '+$s.Game)
    Write-Host ('Duracion.............. '+$s.Duration+' s')
    Write-Host ''
    Write-Host 'RENDIMIENTO'
    Write-Host ('FPS promedio.......... '+$(if($null -ne $s.AvgFps){(F1 $s.AvgFps)+' FPS'}else{'NO DISPONIBLE'}))
    Write-Host ('1% Low................ '+$(if($null -ne $s.Low1){(F1 $s.Low1)+' FPS'}else{'NO DISPONIBLE'}))
    Write-Host ('FPS minimo detectado.. '+$(if($null -ne $s.MinFps){(F1 $s.MinFps)+' FPS'}else{'NO DISPONIBLE'}))
    Write-Host ('Fluidez............... '+$s.Fluidity)
    Write-Host ('Limite de FPS......... '+(FpsCapDisplay $s))
    Write-Host ''
    Write-Host 'USO DEL EQUIPO'
    Write-Host ('CPU................... '+$(if($null -ne $s.ProcCpuAvg){(F1 $s.ProcCpuAvg)+'%'}else{'NO DISPONIBLE'}))
    Write-Host ('Nucleo mas exigido.... '+$(if($null -ne $s.Core95){(F1 $s.Core95)+'%'}else{'NO DISPONIBLE'}))
    Write-Host ('GPU................... '+$(if($null -ne $s.GpuSimple){(F1 $s.GpuSimple)+'%'}else{'NO DISPONIBLE'}))
    Write-Host ('RAM................... '+$(if($null -ne $s.RamPctAvg){(F1 $s.RamPctAvg)+'%'}else{'NO DISPONIBLE'}))
    Write-Host ('Memoria grafica....... '+$s.GpuMemoryStatus)
    Write-Host ''
    Write-Host 'CUELLO DE BOTELLA'
    if($s.FpsCapDetected){
        Write-Host ('Posible limite de '+$s.FpsCap+' FPS / VSync detectado.')
        Write-Host 'No hay evidencia suficiente para confirmar un cuello de botella solo con esta prueba.'
        Write-Host 'Confianza............. BAJA / CAP DETECTADO'
    }else{
        Write-Host (FriendlyBottleneckText $s)
        Write-Host ('Confianza............. '+$s.Confidence)
    }
}
function ShowAdvanced($s){
    WAHeader
    Write-Host 'DATOS AVANZADOS'
    Write-Host ''
    Write-Host 'FRAMES'
    Write-Host ('FPS promedio.......... '+(ValText $s.AvgFps ' FPS'))
    Write-Host ('1% Low................ '+(ValText $s.Low1 ' FPS'))
    Write-Host ('FPS minimo detectado.. '+(ValText $s.MinFps ' FPS'))
    Write-Host ('Frametime promedio.... '+(ValText $s.AvgFrameMs ' ms'))
    Write-Host ('Frametime mediano..... '+(ValText $s.MedianFrameMs ' ms'))
    Write-Host ('Frametime P95......... '+(ValText $s.P95FrameMs ' ms'))
    Write-Host ('Peor frametime........ '+(ValText $s.MaxFrameMs ' ms'))
    Write-Host ('Frames analizados..... '+$s.Frames)
    Write-Host ''
    Write-Host 'CPU'
    Write-Host ('CPU del juego......... '+(ValText $s.ProcCpuAvg '%'))
    Write-Host ('CPU total.............. '+(ValText $s.CpuTotalAvg '%'))
    Write-Host ('Nucleo mas exigido.... '+(ValText $s.Core95 '% (P95)'))
    Write-Host ('Carga extra estimada.. '+(ValText $s.BackgroundCpuAvg '%'))
    Write-Host ''
    Write-Host 'GPU'
    Write-Host ('Carga real de GPU..... '+(ValText $s.GpuBusyPct '%'))
    Write-Host ('Uso GPU de Windows.... '+(ValText $s.GpuWindowsAvg '%'))
    Write-Host ('Memoria dedicada...... '+(ValText $s.DedicatedMaxMB ' MB usados'))
    Write-Host ('Memoria compartida.... '+(ValText $s.SharedMaxMB ' MB usados'))
    Write-Host ''
    Write-Host 'MEMORIA Y DISCO'
    Write-Host ('RAM del sistema....... '+(ValText $s.RamPctAvg '%'))
    Write-Host ('RAM del juego......... '+(ValText $s.GameRamAvgMB ' MB'))
    Write-Host ('Actividad de disco.... '+(ValText $s.DiskPctAvg '%'))
    Write-Host ''
    Write-Host 'NOTAS'
    Write-Host '- P95 muestra un nivel alto frecuente sin depender de un unico pico aislado.'
    Write-Host '- FPS minimo puede representar un tiron, una carga puntual o un cambio de escena.'
    Write-Host '- La memoria grafica muestra uso observado; no todos los drivers exponen un limite total fiable.'
    Write-Host '- GPU Busy aparece como Carga real de GPU en esta pantalla.'
    Write-Host ''
    Read-Host 'Presiona ENTER para volver' | Out-Null
}
function SlowdownPrimary($s){
    if($s.FpsCapDetected){return 'POSIBLE LIMITE DE FPS / VSYNC'}
    if($s.Result -eq 'CPU'){return 'LIMITACION DE CPU'}
    if($s.Result -eq 'GPU'){return 'LIMITACION DE GPU'}
    if($s.Result -eq 'MIXTO / EQUILIBRADO'){return 'CPU Y GPU MUY EXIGIDAS'}
    if($null -ne $s.RamPctAvg -and [double]$s.RamPctAvg -ge 90){return 'PRESION DE MEMORIA RAM'}
    if($null -ne $s.DiskPctAvg -and [double]$s.DiskPctAvg -ge 80 -and $s.Fluidity -eq 'REVISAR'){return 'ACTIVIDAD DE DISCO / CARGA DE RECURSOS'}
    if($s.Fluidity -eq 'REVISAR'){return 'TIRONES O CAIDAS PUNTUALES'}
    return 'NO SE DETECTO UN PROBLEMA PRINCIPAL CLARO'
}
function ShowSlowdown($s){
    while($true){
        WAHeader
        Write-Host '¿QUE ESTA RALENTIZANDO MI JUEGO?'
        Write-Host ''
        Write-Host 'PROBLEMA PRINCIPAL'
        Write-Host (SlowdownPrimary $s)
        Write-Host ''
        if($s.Fluidity -eq 'REVISAR'){
            Write-Host 'La prueba encontro caidas fuertes respecto del rendimiento normal.'
            if($s.Result -eq 'SIN LIMITACION CLARA'){
                Write-Host 'No parecen deberse a un cuello de botella constante de CPU o GPU.'
            }
        }elseif($s.Result -eq 'SIN LIMITACION CLARA'){
            Write-Host 'CPU y GPU conservaron margen y la fluidez general no muestra una alerta fuerte.'
        }else{
            Write-Host $s.Reason
        }
        Write-Host ''
        Write-Host ('CPU................... '+(StatusFromPct $s.Core95 85 95))
        Write-Host ('GPU................... '+(StatusFromPct $s.GpuSimple 85 95))
        Write-Host ('RAM................... '+(StatusFromPct $s.RamPctAvg 80 90))
        Write-Host ('Disco................. '+(StatusFromPct $s.DiskPctAvg 65 85))
        Write-Host ('Segundo plano......... '+(StatusFromPct $s.BackgroundCpuAvg 20 35))
        Write-Host ('Estabilidad de FPS.... '+$s.Fluidity)
        Write-Host ''
        Write-Host 'RECOMENDACIONES'
        if($s.GamingProfileActive){
            Write-Host '[OK] Perfil Gaming de WinTool: ACTIVO.'
        }else{
            Write-Host '[RECOMENDADO] Perfil Gaming de WinTool: NO ACTIVO.'
            Write-Host 'Puede reducir efectos visuales, grabacion en segundo plano y usar Maximo rendimiento de Windows.'
        }
        if($s.FpsCapDetected){
            Write-Host ('[INFO] La prueba estuvo cerca de un limite comun de '+$s.FpsCap+' FPS.')
            Write-Host '[INFO] Para estudiar el cuello de botella puro, repite la prueba sin VSync/cap si quieres y si el juego lo permite.'
        }elseif($s.Result -eq 'CPU'){
            Write-Host '[REVISAR] Cierra procesos pesados y revisa RAM/temperaturas si los FPS siguen limitados.'
        }elseif($s.Result -eq 'GPU'){
            Write-Host '[REVISAR] Baja resolucion o los ajustes graficos mas pesados si buscas mas FPS.'
        }elseif($s.Fluidity -eq 'REVISAR'){
            Write-Host '[REVISAR] Hubo tirones. Repite la prueba evitando menus/cargas para confirmar si son frecuentes.'
            if($null -ne $s.DiskPctAvg -and [double]$s.DiskPctAvg -ge 65){Write-Host '[REVISAR] La actividad de disco fue alta durante parte de la medicion.'}
        }else{
            Write-Host '[OK] No aparece una causa unica importante en esta prueba.'
        }
        if($null -ne $s.BackgroundCpuAvg -and [double]$s.BackgroundCpuAvg -ge 20){
            Write-Host '[INFO] Habia carga de CPU fuera del juego; cerrar apps puede ayudar a estabilizar.'
        }
        Write-Host ''
        Write-Host ('Confianza del analisis: '+$s.Confidence)
        Write-Host ''
        if(-not $s.GamingProfileActive -and $ToolsDir -and $BackupsDir -and (Test-Path (Join-Path $ToolsDir 'GamingProfileV54.ps1'))){
            Write-Host '[1] Activar Perfil Gaming de WinTool'
            Write-Host '[2] Volver al resultado'
            $op=(Read-Host 'Elegir').Trim()
            if($op -eq '1'){
                $ok=(Read-Host 'Aplicar Perfil Gaming ahora? [S/N]').Trim()
                if($ok -match '^[Ss]$'){
                    & (Join-Path $ToolsDir 'GamingProfileV54.ps1') -Mode Apply -BackupDir $BackupsDir
                    $s.GamingProfileActive=(GamingProfileActive)
                    Write-Host ''
                    Read-Host 'Presiona ENTER para continuar' | Out-Null
                }
                continue
            }
            if($op -eq '2'){return}
        }else{
            Read-Host 'Presiona ENTER para volver al resultado' | Out-Null
            return
        }
    }
}
function OptimizeGame($s){
 while($true){
   WAHeader
   Write-Host 'OPTIMIZAR JUEGO'
   Write-Host ''
   $pidToUse=0
   try{$pidToUse=[int]$s.PID}catch{}
   if($pidToUse -le 0){
     Write-Host '[REVISAR] Esta prueba no tiene un PID valido.'
     Read-Host 'Presiona ENTER para volver'|Out-Null;return
   }
   $proc=Get-Process -Id $pidToUse -ErrorAction SilentlyContinue
   if(-not $proc){
     Write-Host '[INFO] El juego de esta prueba ya no esta abierto.'
     Write-Host 'Abre el juego y realiza una prueba nueva para optimizar ese proceso.'
     Read-Host 'Presiona ENTER para volver'|Out-Null;return
   }
   $optimizer=Join-Path $ToolsDir 'GameOptimizerV58.ps1'
   if(-not(Test-Path -LiteralPath $optimizer)){
     Write-Host '[REVISAR] Falta el componente de optimizacion del juego.'
     Read-Host 'Presiona ENTER para volver'|Out-Null;return
   }
   & $optimizer -Mode Inspect -TargetPid $pidToUse -StateDir $ConfigDir
   Write-Host ''
   Write-Host '[1] APLICAR OPTIMIZACION TEMPORAL'
   Write-Host '[2] RESTAURAR CAMBIOS DE WINTOOL'
   Write-Host '[3] VOLVER'
   $o=(Read-Host 'Elegir').Trim()
   if($o -eq '1'){
     Write-Host ''
     Write-Host '[INFO] WinTool solo eleva prioridades inferiores a ABOVE NORMAL.'
     Write-Host '[INFO] Si ya usas Above Normal, High o Realtime, NO la baja ni la reemplaza.'
     Write-Host '[INFO] No toca afinidad, GPU Priority, HPET, BCD ni Realtime.'
     $c=(Read-Host 'Aplicar? [S/N]').Trim()
     if($c -match '^[Ss]$'){
       & $optimizer -Mode Apply -TargetPid $pidToUse -StateDir $ConfigDir
       Write-Host ''
       Write-Host '[OK] Optimizacion aplicada al proceso actual.'
       Write-Host '[INFO] Usa RESTAURAR antes de cerrar WinAnalyzer si quieres devolver el estado original.'
       Read-Host 'Presiona ENTER para continuar'|Out-Null
     }
     continue
   }
   if($o -eq '2'){
     & $optimizer -Mode Restore -TargetPid $pidToUse -StateDir $ConfigDir
     Read-Host 'Presiona ENTER para continuar'|Out-Null
     continue
   }
   if($o -eq '3'){return}
 }
}
function PostResultMenu($s){
    while($true){
        ShowSimpleResult $s
        Write-Host ''
        Write-Host '[1] DATOS AVANZADOS'
        Write-Host '[2] ¿QUE ESTA RALENTIZANDO MI JUEGO?'
        Write-Host '[3] OPTIMIZAR JUEGO'
        Write-Host '[4] FINALIZAR'
        $op=(Read-Host 'Elegir').Trim()
        if($op -eq '1'){ShowAdvanced $s;continue}
        if($op -eq '2'){ShowSlowdown $s;continue}
        if($op -eq '3'){OptimizeGame $s;continue}
        if($op -eq '4'){return}
        Write-Host '[REVISAR] Elige 1, 2, 3 o 4.'
        Start-Sleep -Milliseconds 600
    }
}
function PersistResult($summary,[string]$txtPath,[string]$jsonPath,[string]$lastPath){
    $lines=New-Object System.Collections.Generic.List[string]
    $lines.Add('WinAnalyzer V1.0 - RESULTADO')
    $lines.Add('')
    $lines.Add(('Juego: '+$summary.Game))
    $lines.Add(('Fecha: '+$summary.Date))
    $lines.Add(('Duracion: '+$summary.Duration+' s'))
    $lines.Add('')
    $lines.Add('RESULTADO SIMPLE')
    $lines.Add(('FPS promedio: '+(ValText $summary.AvgFps ' FPS')))
    $lines.Add(('1% Low: '+(ValText $summary.Low1 ' FPS')))
    $lines.Add(('FPS minimo detectado: '+(ValText $summary.MinFps ' FPS')))
    $lines.Add(('Fluidez: '+$summary.Fluidity))
    $lines.Add(('Limite/VSync: '+$summary.FpsCapText))
    $lines.Add(('CPU juego: '+(ValText $summary.ProcCpuAvg '%')))
    $lines.Add(('Nucleo mas exigido: '+(ValText $summary.Core95 '%')))
    $lines.Add(('GPU: '+(ValText $summary.GpuSimple '%')))
    $lines.Add(('RAM: '+(ValText $summary.RamPctAvg '%')))
    $lines.Add(('Cuello de botella: '+$summary.Result+' | Confianza '+$summary.Confidence))
    $lines.Add(('Motivo: '+$summary.Reason))
    $lines.Add('')
    $lines.Add('DATOS AVANZADOS')
    $lines.Add(('Frames: '+$summary.Frames))
    $lines.Add(('Frametime promedio: '+(ValText $summary.AvgFrameMs ' ms')))
    $lines.Add(('Frametime P95: '+(ValText $summary.P95FrameMs ' ms')))
    $lines.Add(('Peor frametime: '+(ValText $summary.MaxFrameMs ' ms')))
    $lines.Add(('GPU Busy: '+(ValText $summary.GpuBusyPct '%')))
    $lines.Add(('GPU Windows: '+(ValText $summary.GpuWindowsAvg '%')))
    $lines.Add(('CPU total: '+(ValText $summary.CpuTotalAvg '%')))
    $lines.Add(('Carga extra CPU estimada: '+(ValText $summary.BackgroundCpuAvg '%')))
    $lines.Add(('Disco promedio: '+(ValText $summary.DiskPctAvg '%')))
    $lines.Add(('RAM juego: '+(ValText $summary.GameRamAvgMB ' MB')))
    $lines.Add(('Memoria GPU dedicada: '+(ValText $summary.DedicatedMaxMB ' MB')))
    $lines.Add(('Memoria GPU compartida: '+(ValText $summary.SharedMaxMB ' MB')))
    $lines.Add('')
    $lines.Add('NOTAS')
    $lines.Add('- Este resultado describe esta prueba y no una compatibilidad absoluta entre CPU/GPU.')
    $lines.Add('- El FPS minimo puede representar un tiron, carga o cambio de escena real.')
    $lines.Add('- La memoria grafica se informa sin declarar saturacion cuando el driver no expone un total fiable.')
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
    Write-Host 'PRESENTMON - COMPONENTE DE WinAnalyzer'
    Write-Host ''
    Write-Host ('Estado............... '+$(if(-not $v.Exists){'NO ENCONTRADO'}elseif($v.HashOk){'INTEGRADO Y VERIFICADO'}else{'ARCHIVO DISTINTO / NO VERIFICADO'}))
    Write-Host ('Version esperada..... '+$ExpectedVersion)
    if($v.Version){Write-Host ('Version del archivo... '+$v.Version)}
    if($v.Exists){Write-Host ('SHA-256 verificado.... '+$(if($v.HashOk){'SI'}else{'NO'}))}
    Write-Host ('Firma Windows......... '+$v.Signature)
    Write-Host ''
    Write-Host 'Si el componente falta, WinAnalyzer puede hacer una prueba basica sin FPS/frametimes.'
    exit 0
}

if($Mode -eq 'Info'){
    Write-Host 'COMO FUNCIONA WinAnalyzer'
    Write-Host ''
    Write-Host '1. Eliges un juego que ya esta abierto.'
    Write-Host '2. PresentMon registra frames, frametime y GPU Busy.'
    Write-Host '3. WinAnalyzer mide CPU por nucleo, GPU, RAM, memoria grafica y actividad de disco.'
    Write-Host '4. WinAnalyzer combina las mediciones y clasifica la prueba como:'
    Write-Host '   CPU / GPU / MIXTO / SIN LIMITACION CLARA / NO CONCLUYENTE.'
    Write-Host '5. Siempre muestra una confianza: ALTA, MEDIA o BAJA.'
    Write-Host ''
    Write-Host 'No usa una base de datos de CPUs/GPUs ni inventa un porcentaje de bottleneck.'
    Write-Host 'Un resultado CPU/GPU solo describe el juego, escena y ajustes usados durante esa prueba.'
    Write-Host ''
    Write-Host 'VRAM / memoria grafica:'
    Write-Host 'Windows puede exponer memoria dedicada y compartida usada por el proceso.'
    Write-Host 'En una iGPU es normal usar memoria compartida. WinAnalyzer V1.0 no declara VRAM agotada'
    Write-Host 'porque algunos drivers no ofrecen un total fiable de memoria de video.'
    exit 0
}

if($Mode -eq 'Last'){
    if(-not(Test-Path $lastFile)){WAHeader;Write-Host '[INFO] Todavia no hay una prueba guardada.';exit 0}
    try{$s=Get-Content $lastFile -Raw|ConvertFrom-Json}catch{WAHeader;Write-Host '[ERROR] Ultima prueba ilegible.';exit 2}
    if($null -eq $s.Fluidity){
        $fl='NO DISPONIBLE'
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
        $s|Add-Member -NotePropertyName FpsCapText -NotePropertyValue 'NO DISPONIBLE EN ESTA PRUEBA' -Force
    }
    if($null -eq $s.MedianFrameMs){$s|Add-Member -NotePropertyName MedianFrameMs -NotePropertyValue $null -Force}
    PostResultMenu $s
    exit 0
}

if($Mode -eq 'History'){
    $files=@(Get-ChildItem -LiteralPath $testsRoot -Filter '*.json' -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending|Select-Object -First 12)
    if($files.Count -eq 0){Write-Host '[INFO] Todavia no hay historial de WinAnalyzer.';exit 0}
    Write-Host 'HISTORIAL DE WinAnalyzer'
    Write-Host ''
    foreach($f in $files){
        try{
            $s=Get-Content $f.FullName -Raw|ConvertFrom-Json
            $fps=if($null -ne $s.AvgFps){F1 $s.AvgFps}else{'N/D'}
            $low=if($null -ne $s.Low1){F1 $s.Low1}else{'N/D'}
            Write-Host ('{0} | {1} | {2} ({3}) | FPS {4} | 1% {5}' -f $s.Date,$s.Game,$s.Result,$s.Confidence,$fps,$low)
        }catch{}
    }
    Write-Host ''
    Write-Host ('Carpeta de pruebas: '+$testsRoot)
    exit 0
}

# ANALYZE
WAHeader
Write-Host 'ANALIZAR MI JUEGO'
Write-Host 'Test de FPS, fluidez y cuello de botella'
Write-Host ''
Write-Host 'ANTES DE EMPEZAR'
Write-Host '- Cierra la mayor cantidad de aplicaciones que no necesites.'
Write-Host '- Deja abierto el launcher/Discord solo si realmente los usas al jugar.'
Write-Host '- Abre el juego y entra a una partida o zona representativa.'
Write-Host '- Evita menus, pantallas de carga y quedarse quieto toda la prueba.'
Write-Host '- WinAnalyzer NO cerrara programas automaticamente.'
Write-Host '- Durante la prueba juega con normalidad para que el resultado sea representativo.'
Write-Host ''
$ready=(Read-Host 'Cuando el juego este listo, escribe LISTO. Escribe C para cancelar').Trim()
if($ready -match '^[Cc]$'){exit 0}
if($ready.ToUpperInvariant() -ne 'LISTO'){Write-Host '[INFO] Prueba cancelada.';exit 0}

$target=ReadTarget
if($null -eq $target){Write-Host '[INFO] Prueba cancelada.';exit 0}
$duration=ReadDuration
$targetPid=[int]$target.PID
try{$targetProc=Get-Process -Id $targetPid -ErrorAction Stop}catch{Write-Host '[ERROR] El proceso ya no esta abierto.';exit 2}

$pmVerify=VerifyPresentMon
$usePm=$pmVerify.Exists -and $pmVerify.HashOk
if(-not $usePm){
    Write-Host ''
    if(-not $pmVerify.Exists){Write-Host '[INFO] PresentMon integrado no esta disponible.'}
    else{Write-Host '[REVISAR] PresentMon no coincide con el componente verificado de WinTool.'}
    Write-Host 'La prueba puede continuar en modo BASICO, sin FPS/1% Low/GPU Busy de PresentMon.'
    $ans=(Read-Host 'Continuar en modo basico? [S/N]').Trim()
    if($ans -notmatch '^[Ss]$'){exit 0}
}

Write-Host ''
Write-Host ('Juego seleccionado: '+$target.Friendly+' ('+$target.Name+'.exe)')
Write-Host ('Duracion: '+$duration+' segundos')
Write-Host ''
Write-Host 'Tienes 5 segundos para volver al juego...'
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
        Write-Host '[INFO] PresentMon no pudo iniciarse. Continuando con medicion basica.'
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
        Write-Host ('[{0}] {1,3}%  Analizando {2}' -f $bar,$pct,$target.Friendly)
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
$gpuMemStatus=if($null -ne $dedMax -or $null -ne $shrMax){'SIN ALERTA'}else{'NO DISPONIBLE'}
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
    FpsCapText=$(if([string]::IsNullOrWhiteSpace([string]$capInfo.Text)){'NO DETECTADO'}else{[string]$capInfo.Text})
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
