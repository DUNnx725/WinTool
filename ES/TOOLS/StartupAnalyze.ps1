param([string]$OutFile)
$x=Get-CimInstance Win32_StartupCommand|Select-Object Name,Command,Location,User
$r=@('WINTOOL V5 - INICIO',('Entradas detectadas: '+@($x).Count),'');$r+=($x|Format-Table -AutoSize|Out-String);$r+='WinTool no deshabilita entradas automaticamente.';$r|Set-Content $OutFile -Encoding UTF8; $r|ForEach-Object{Write-Host $_}
