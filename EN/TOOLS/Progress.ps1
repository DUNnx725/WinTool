param([string]$Label='Processing',[int]$Percent=50)
$Percent=[Math]::Max(0,[Math]::Min(100,$Percent)); $width=32; $n=[int][Math]::Round($width*$Percent/100)
$bar=('='*$n)+('.'*($width-$n)); Write-Host ('[{0}] {1,3}%  {2}' -f $bar,$Percent,$Label)
