param([string]$OutFile)
$x=Get-CimInstance Win32_StartupCommand|Select-Object Name,Command,Location,User
$r=@('WINTOOL - STARTUP',('Entries detected: '+@($x).Count),'');$r+=($x|Format-Table -AutoSize|Out-String);$r+='WinTool does not disable startup entries automatically.';$r|Set-Content $OutFile -Encoding UTF8; $r|ForEach-Object{Write-Host $_}
