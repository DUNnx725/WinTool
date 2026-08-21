param([Parameter(Mandatory=$true)][string]$OutFile)
$ErrorActionPreference='SilentlyContinue'
$os=Get-CimInstance Win32_OperatingSystem
$cpu=Get-CimInstance Win32_Processor|Select-Object -First 1
$cs=Get-CimInstance Win32_ComputerSystem
$c=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$ramTotal=[math]::Round($cs.TotalPhysicalMemory/1GB,1)
$ramFree=[math]::Round($os.FreePhysicalMemory*1KB/1GB,1)
$ramPct=[math]::Round((1-($ramFree/$ramTotal))*100)
$procs=@(Get-Process).Count
$startup=@(Get-CimInstance Win32_StartupCommand).Count
$freePct=if($c.Size){[math]::Round(($c.FreeSpace/$c.Size)*100)}else{0}
$net='NO CONFIRMADO';$ping=$null
try{
 $p=Test-Connection 1.1.1.1 -Count 4 -ErrorAction Stop
 if($p){$net='OK';$ping=[math]::Round(($p|Measure-Object ResponseTime -Average).Average,1)}
}catch{}
$trim=(fsutil behavior query DisableDeleteNotify 2>$null|Out-String)
$trimOk=($trim -match 'DisableDeleteNotify\s*=\s*0')

$lines=@()
$lines+='GENERAL ANALYSIS'
$lines+=('Date: '+(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'))
$lines+=''
$lines+='SUMMARY'
$lines+=('Windows............. '+$os.Caption.Replace('Microsoft ',''))
$lines+=('Processor.......... '+$cpu.Name.Trim())
$lines+=('Memory.............. '+$ramTotal+' GB | '+$ramPct+'% in use')
$lines+=('Processes........... '+$procs)
$lines+=('Startup apps: '+$startup)
$lines+=('C: free............ '+[math]::Round($c.FreeSpace/1GB,1)+' GB ('+$freePct+'%)')
$lines+=('TRIM................ '+$(if($trimOk){'ACTIVE'}else{'CHECK'}))
$lines+=('Internet............ '+$net+$(if($ping -ne $null){' | '+$ping+' ms'}else{''}))
$lines+=''
$lines+='KEY INFORMATION'
if($ramPct -ge 85){$lines+='[CHECK] RAM usage is very high right now.'}elseif($ramPct -ge 70){$lines+='[INFO] RAM usage is moderate/high in this measurement.'}else{$lines+='[OK] RAM usage is normal in this measurement.'}
if($freePct -lt 15){$lines+='[CHECK] C: has low free space.'}elseif($freePct -lt 20){$lines+='[INFO] C: is relatively full.'}else{$lines+='[OK] C: has a reasonable amount of free space.'}
if($startup -gt 12){$lines+='[CHECK] Many apps are configured to start with Windows.'}else{$lines+='[OK] Startup app count shows no warning.'}
if(-not $trimOk){$lines+='[CHECK] Could not confirm that TRIM is active.'}
if($net -eq 'OK'){$lines+='[OK] Basic connectivity available.'}else{$lines+='[INFO] Internet connectivity could not be confirmed during this test.'}
$lines+=''
$lines+='This analysis does not change anything. Extended technical data is kept in advanced reports.'
$lines|ForEach-Object{Write-Host $_}
$lines|Set-Content -LiteralPath $OutFile -Encoding UTF8
exit 0
