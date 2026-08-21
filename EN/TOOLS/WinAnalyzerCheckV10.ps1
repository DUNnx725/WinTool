param([Parameter(Mandatory=$true)][string]$PresentMonPath)
$expected='9bec3083069f58f911e6a512f4806db51a27bd096103087bc1d05ef54c80a191'
if(-not(Test-Path -LiteralPath $PresentMonPath)){
    Write-Output 'PRESENTMON|NOT FOUND'
    exit 0
}
try{
    $h=(Get-FileHash -LiteralPath $PresentMonPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if($h -eq $expected){Write-Output 'PRESENTMON|READY'}else{Write-Output 'PRESENTMON|NOT VERIFIED'}
}catch{Write-Output 'PRESENTMON|NOT VERIFIED'}
exit 0
