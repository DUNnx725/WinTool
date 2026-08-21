param(
    [ValidateSet('Header','Progress','Result')]
    [string]$Mode='Header',
    [string]$Label='',
    [int]$Percent=0,
    [int]$Code=0
)
if($Mode -eq 'Header'){
    Write-Host '============================================================================================'
    Write-Host '                                      WinAnalyzer'
    Write-Host '                                         V1.0'
    Write-Host '============================================================================================'
    Write-Host '                         Rendimiento y diagnostico gaming'
    Write-Host ''
    exit 0
}
if($Mode -eq 'Progress'){
    $Percent=[math]::Max(0,[math]::Min(100,$Percent))
    $filled=[math]::Floor($Percent/5)
    $bar=('='*$filled)+('.'*(20-$filled))
    Write-Host ('[{0}] {1,3}%  {2}' -f $bar,$Percent,$Label)
    exit 0
}
if($Mode -eq 'Result'){
    if($Code -eq 0){Write-Host '[OK] Prueba finalizada.';exit 0}
    Write-Host ('[REVISAR] WinAnalyzer termino con codigo {0}.' -f $Code)
    Write-Host 'La herramienta seguira abierta para que puedas revisar el mensaje.'
    exit 0
}
