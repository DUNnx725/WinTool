param([Parameter(Mandatory)][string]$OutFile)
$cmd=Get-Command speedtest.exe -ErrorAction SilentlyContinue;if(!$cmd){@('[NO DISPONIBLE] Ookla Speedtest CLI no esta instalado o no esta en PATH.','Instalacion oficial con winget: winget install --id Ookla.Speedtest.CLI')|Set-Content $OutFile -Encoding UTF8;exit 2}; & $cmd.Source --accept-license --accept-gdpr 2>&1|Tee-Object -FilePath $OutFile
