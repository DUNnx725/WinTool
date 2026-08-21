param([Parameter(Mandatory=$true)][string]$PresentMonPath)
$expected='9bec3083069f58f911e6a512f4806db51a27bd096103087bc1d05ef54c80a191'
if(-not(Test-Path -LiteralPath $PresentMonPath)){
    Write-Output 'PRESENTMON|NO ENCONTRADO'
    exit 0
}
try{
    $h=(Get-FileHash -LiteralPath $PresentMonPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if($h -eq $expected){Write-Output 'PRESENTMON|LISTO'}else{Write-Output 'PRESENTMON|NO VERIFICADO'}
}catch{Write-Output 'PRESENTMON|NO VERIFICADO'}
exit 0
