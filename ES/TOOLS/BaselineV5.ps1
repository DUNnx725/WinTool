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
    Write-Host '[OK] Linea base guardada.'
    exit 0
}
if(!(Test-Path $DataFile)){Write-Host '[INFO] Primero crea una linea base.';exit 0}
$o=Get-Content $DataFile -Raw|ConvertFrom-Json
Write-Host 'COMPARACION'
Write-Host ('Procesos:    '+$o.Processes+' -> '+$n.Processes)
Write-Host ('RAM libre:   '+$o.FreeRAM_MB+' -> '+$n.FreeRAM_MB+' MB')
Write-Host ('Inicio:      '+$o.Startup+' -> '+$n.Startup)
Write-Host ('C: libre:    '+$o.C_FreeGB+' -> '+$n.C_FreeGB+' GB')
exit 0
