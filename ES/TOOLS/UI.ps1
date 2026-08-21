param(
    [ValidateSet('Header','Progress','Result','Section')]
    [string]$Mode='Header',
    [string]$Label='',
    [int]$Percent=0,
    [int]$Code=0
)
if($Mode -eq 'Header'){
    Write-Host '===================================================================================================='
    $v=(& (Join-Path $PSScriptRoot 'Version.ps1') -Mode Display 2>$null)
    if(-not $v){$v=''}
    Write-Host ('                                        WINTOOL '+$v)
    Write-Host '===================================================================================================='
    Write-Host '                       Diagnostico - Mantenimiento - Optimizacion - Herramientas'
    Write-Host ''
    exit 0
}
if($Mode -eq 'Section'){
    Write-Host ''
    Write-Host ('--- '+$Label+' ---')
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
    if($Code -eq 0){Write-Host '[OK] Operacion terminada.';exit 0}
    Write-Host ('[REVISAR] La operacion termino con codigo {0}.' -f $Code)
    Write-Host 'WinTool permanecera abierto. Revisa el mensaje mostrado arriba.'
    exit 0
}
