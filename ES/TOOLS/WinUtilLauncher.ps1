param()
Write-Host 'WINUTIL - CHRIS TITUS TECH'
Write-Host ''
Write-Host 'Herramienta externa avanzada. WinTool no registra ni revierte los cambios hechos dentro de WinUtil.'
Write-Host 'Se usara el comando estable publicado por el proyecto oficial.'
Write-Host ''
$ans=Read-Host 'Escribe ABRIR para descargar y ejecutar WinUtil desde su fuente oficial'
if($ans -ne 'ABRIR'){Write-Host 'Cancelado.';exit 0}
try {
 $script=Invoke-RestMethod -Uri 'https://christitus.com/win' -UseBasicParsing
 & ([ScriptBlock]::Create($script))
 exit 0
} catch {
 Write-Host ('[ERROR] No se pudo cargar WinUtil: '+$_.Exception.Message)
 exit 2
}
