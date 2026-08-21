param([ValidateSet('Create','Compare')][string]$Mode,[string]$DataFile,[string]$ReportsDir)
$ErrorActionPreference='Stop'
function Snap{
    $os=Get-CimInstance Win32_OperatingSystem
    $vol=Get-Volume -DriveLetter C
    [pscustomobject]@{
        Date=(Get-Date)
        Processes=@(Get-Process).Count
        FreeRAM_MB=[math]::Round($os.FreePhysicalMemory/1KB,0)
        Startup=@(Get-CimInstance Win32_StartupCommand).Count
        C_FreeGB=[math]::Round($vol.SizeRemaining/1GB,1)
    }
}
$n=Snap
if($Mode -eq 'Create'){
    $n|ConvertTo-Json|Set-Content $DataFile -Encoding UTF8
    Write-Host '[OK] Baseline saved.'
    exit 0
}
if(!(Test-Path $DataFile)){Write-Host '[INFO] Create a baseline first.';exit 0}
$o=Get-Content $DataFile -Raw|ConvertFrom-Json
Write-Host 'COMPARISON'
Write-Host ('Processes:    '+$o.Processes+' -> '+$n.Processes)
Write-Host ('Free RAM:   '+$o.FreeRAM_MB+' -> '+$n.FreeRAM_MB+' MB')
Write-Host ('Startup:      '+$o.Startup+' -> '+$n.Startup)
Write-Host ('Free C: space:    '+$o.C_FreeGB+' -> '+$n.C_FreeGB+' GB')
exit 0
