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
    Write-Host '                         Gaming performance and diagnostics'
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
    if($Code -eq 0){Write-Host '[OK] Test completed.';exit 0}
    Write-Host ('[CHECK] WinAnalyzer ended with code {0}.' -f $Code)
    Write-Host 'The tool will remain open so you can review the message.'
    exit 0
}
