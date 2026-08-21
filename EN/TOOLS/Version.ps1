param(
    [ValidateSet('Plain','Display')]
    [string]$Mode='Plain'
)
$Version='1.0.0'
if($Mode -eq 'Display'){ Write-Output ('V'+$Version) }
else{ Write-Output $Version }
exit 0
