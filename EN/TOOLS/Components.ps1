param()
$items=@(
 [pscustomobject]@{Name='PowerShell 5.1+';Found=($PSVersionTable.PSVersion.Major -ge 5);How='Incluido en Windows'},
 [pscustomobject]@{Name='WinGet';Found=[bool](Get-Command winget.exe -ErrorAction SilentlyContinue);How='Microsoft App Installer'},
 [pscustomobject]@{Name='Ookla Speedtest CLI';Found=[bool](Get-Command speedtest.exe -ErrorAction SilentlyContinue);How='winget install Ookla.Speedtest.CLI'}
)
Write-Host 'OPTIONAL COMPONENTS'
Write-Host ''
foreach($i in $items){
 Write-Host ('{0,-24} {1,-12} {2}' -f $i.Name,$(if($i.Found){'AVAILABLE'}else{'NOT INSTALLED'}),$i.How)
}
Write-Host ''
Write-Host 'WinTool does not download unknown executables or install components without confirmation.'
exit 0
