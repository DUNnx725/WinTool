param([Parameter(Mandatory)][string]$OutFile)
$cmd=Get-Command speedtest.exe -ErrorAction SilentlyContinue;if(!$cmd){@('[NOT AVAILABLE] Ookla Speedtest CLI is not installed or is not in PATH.','Official installation with WinGet: winget install --id Ookla.Speedtest.CLI')|Set-Content $OutFile -Encoding UTF8;exit 2}; & $cmd.Source --accept-license --accept-gdpr 2>&1|Tee-Object -FilePath $OutFile
