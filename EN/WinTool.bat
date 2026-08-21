@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
chcp 65001 >nul 2>&1
color 0B
mode con cols=100 lines=40 >nul 2>&1

set "BASE=%~dp0"
set "TOOLS=%BASE%TOOLS"
set "VERSION=UNKNOWN"
for /f "usebackq delims=" %%V in (`powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\Version.ps1" -Mode Plain 2^>nul`) do set "VERSION=%%V"
set "VERSION_SAFE=!VERSION:.=_!"
title WinTool V!VERSION!
set "BUNDLED=%BASE%COMPONENTES"
set "PRESENTMON=%BUNDLED%\PresentMon\PresentMon-2.5.1-x64.exe"
set "BOOTCONFIG=%BASE%CONFIG"
if not exist "%BOOTCONFIG%" mkdir "%BOOTCONFIG%" >nul 2>&1

for /f "tokens=1-2 delims=|" %%A in ('powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\StoragePathsV541.ps1" -Mode Init -BaseDir "%BASE%" -ConfigFile "%BOOTCONFIG%\StorageMode.json"') do (
    if "%%A"=="REPORTES" set "REPORTS=%%B"
    if "%%A"=="BACKUPS" set "BACKUPS=%%B"
    if "%%A"=="LOGS" set "LOGS=%%B"
    if "%%A"=="CONFIG" set "CONFIG=%%B"
    if "%%A"=="DRIVERS" set "DRIVERS=%%B"
    if "%%A"=="COMPONENTS" set "COMPONENTS=%%B"
)
if not defined REPORTS goto STORAGE_FAIL
set "HISTORY=%BACKUPS%\Historial_V!VERSION_SAFE!.json"

net session >nul 2>&1
if "%errorlevel%"=="0" goto AFTER_ADMIN
cls
echo WinTool requires administrator privileges for system diagnostics and maintenance.
echo Requesting permission...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -WorkingDirectory '%~dp0' -Verb RunAs"
exit /b

:AFTER_ADMIN
cd /d "%~dp0"

for /f "tokens=1-2 delims=|" %%A in ('powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\StoragePathsV541.ps1" -Mode Init -BaseDir "%BASE%" -ConfigFile "%BOOTCONFIG%\StorageMode.json"') do (
    if "%%A"=="REPORTES" set "REPORTS=%%B"
    if "%%A"=="BACKUPS" set "BACKUPS=%%B"
    if "%%A"=="LOGS" set "LOGS=%%B"
    if "%%A"=="CONFIG" set "CONFIG=%%B"
    if "%%A"=="DRIVERS" set "DRIVERS=%%B"
    if "%%A"=="COMPONENTS" set "COMPONENTS=%%B"
)
if not defined REPORTS goto STORAGE_FAIL
set "HISTORY=%BACKUPS%\Historial_V!VERSION_SAFE!.json"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\SelfTest.ps1" -ToolsDir "%TOOLS%" -LogFile "%LOGS%\SelfTest_Latest.txt" -ReportsDir "%REPORTS%" -BackupsDir "%BACKUPS%" -ConfigDir "%CONFIG%" -PresentMonPath "%PRESENTMON%" -BatFile "%~f0"
if not "%errorlevel%"=="0" goto SELFTEST_FAIL

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo Preparing environment...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Checking Windows" -Percent 20
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Verifying scripts" -Percent 40
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Preparing reports and backups" -Percent 60
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Checking connectivity" -Percent 80
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Loading WinTool" -Percent 100
timeout /t 1 /nobreak >nul
goto MAIN

:SELFTEST_FAIL
echo.
echo [ERROR] WinTool detected a problem before startup.
echo Check: %LOGS%\SelfTest_Latest.txt
echo Press any key to continue . . .
pause >nul
goto END

:MAIN
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
set "NET=UNKNOWN"
set "REBOOT=UNKNOWN"
for /f "tokens=1-2 delims=|" %%A in ('powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\StartupStatus.ps1" 2^>nul') do (
    if "%%A"=="INTERNET" set "NET=%%B"
    if "%%A"=="REBOOT" set "REBOOT=%%B"
)
echo Quick status: Internet !NET! ^| Pending restart !REBOOT!
echo.
echo [1] PC STATUS                    Quick overview, diagnostics and alerts
echo [2] OPTIMIZE                     Selected and reversible changes
echo [3] SMART MAINTENANCE            Analyze, clean and maintain in a controlled way
echo [4] TOOLS                        Network, drivers, repair, software and performance
echo [5] SETTINGS / RESTORE           Backups, history, reports and rollback
echo [6] WinAnalyzer V1.0             FPS, smoothness and bottleneck analysis
echo.
echo [0] EXIT
echo.
choice /c 1234560 /n /m "Choose: "
if errorlevel 7 goto END
if errorlevel 6 goto WINANALYZER_MENU
if errorlevel 5 goto CONFIG_MENU
if errorlevel 4 goto TOOLS_MENU
if errorlevel 3 goto MAINT_MENU
if errorlevel 2 goto OPT_MENU
if errorlevel 1 goto DASHBOARD
goto MAIN

:WINANALYZER_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinAnalyzerUIV1.ps1" -Mode Header
set "PMSTATUS=UNKNOWN"
for /f "tokens=1-2 delims=|" %%A in ('powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinAnalyzerCheckV10.ps1" -PresentMonPath "%PRESENTMON%"') do (
    if "%%A"=="PRESENTMON" set "PMSTATUS=%%B"
)
echo PresentMon.............. !PMSTATUS!
echo.
echo [1] ANALYZE MY GAME
echo     FPS, smoothness and bottleneck test
echo.
echo [2] LAST TEST
echo [3] HISTORY
echo [4] HOW IT WORKS
echo [5] COMPONENTS
echo [6] BACK TO WINTOOL
choice /c 123456 /n /m "Choose: "
if errorlevel 6 goto MAIN
if errorlevel 5 goto WINANALYZER_COMPONENT
if errorlevel 4 goto WINANALYZER_INFO
if errorlevel 3 goto WINANALYZER_HISTORY
if errorlevel 2 goto WINANALYZER_LAST
if errorlevel 1 goto WINANALYZER_ANALYZE
goto WINANALYZER_MENU

:WINANALYZER_ANALYZE
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinAnalyzerV10.ps1" -Mode Analyze -PresentMonPath "%PRESENTMON%" -ReportsRoot "%REPORTS%" -ConfigDir "%CONFIG%" -BackupsDir "%BACKUPS%" -ToolsDir "%TOOLS%" -UiScript "%TOOLS%\WinAnalyzerUIV1.ps1"
set "RC=!errorlevel!"
if not "!RC!"=="0" powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinAnalyzerUIV1.ps1" -Mode Result -Code !RC!
echo Press any key to continue . . .
pause >nul
goto WINANALYZER_MENU

:WINANALYZER_LAST
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinAnalyzerV10.ps1" -Mode Last -PresentMonPath "%PRESENTMON%" -ReportsRoot "%REPORTS%" -ConfigDir "%CONFIG%" -BackupsDir "%BACKUPS%" -ToolsDir "%TOOLS%" -UiScript "%TOOLS%\WinAnalyzerUIV1.ps1"
echo Press any key to continue . . .
pause >nul
goto WINANALYZER_MENU

:WINANALYZER_HISTORY
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinAnalyzerUIV1.ps1" -Mode Header
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinAnalyzerV10.ps1" -Mode History -PresentMonPath "%PRESENTMON%" -ReportsRoot "%REPORTS%" -ConfigDir "%CONFIG%" -BackupsDir "%BACKUPS%" -ToolsDir "%TOOLS%" -UiScript "%TOOLS%\WinAnalyzerUIV1.ps1"
echo Press any key to continue . . .
pause >nul
goto WINANALYZER_MENU

:WINANALYZER_INFO
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinAnalyzerUIV1.ps1" -Mode Header
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinAnalyzerV10.ps1" -Mode Info -PresentMonPath "%PRESENTMON%" -ReportsRoot "%REPORTS%" -ConfigDir "%CONFIG%" -BackupsDir "%BACKUPS%" -ToolsDir "%TOOLS%" -UiScript "%TOOLS%\WinAnalyzerUIV1.ps1"
echo Press any key to continue . . .
pause >nul
goto WINANALYZER_MENU

:WINANALYZER_COMPONENT
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinAnalyzerUIV1.ps1" -Mode Header
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinAnalyzerV10.ps1" -Mode Component -PresentMonPath "%PRESENTMON%" -ReportsRoot "%REPORTS%" -ConfigDir "%CONFIG%" -BackupsDir "%BACKUPS%" -ToolsDir "%TOOLS%" -UiScript "%TOOLS%\WinAnalyzerUIV1.ps1"
echo.
echo License: %BUNDLED%\PresentMon\LICENSE.txt
echo Press any key to continue . . .
pause >nul
goto WINANALYZER_MENU

:DASHBOARD
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
for /f %%I in ('powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%I"
set "OUT=%REPORTS%\PC_Status_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Reading hardware" -Percent 20
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\Dashboard.ps1" -OutFile "!OUT!"
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Dashboard updated" -Percent 100
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo.
echo [1] Smart alerts
echo     Translates Windows events into simple alerts and separates INFO from real errors.
echo [2] What is slowing down my PC?
echo [3] General analysis
echo [4] Advanced analysis
echo [5] Open latest report
echo [6] Back
choice /c 123456 /n /m "Choose: "
if errorlevel 6 goto MAIN
if errorlevel 5 goto DASH_OPEN_REPORT
if errorlevel 4 goto ANALYZE_ADV
if errorlevel 3 goto ANALYZE_GENERAL
if errorlevel 2 goto QUICK_DIAG
if errorlevel 1 goto SMART_ALERTS
goto DASHBOARD

:SMART_ALERTS
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
for /f %%I in ('powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%I"
set "OUT=%REPORTS%\Smart_Alerts_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Checking important events" -Percent 25
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\SmartAlertsV55.ps1" -OutFile "!OUT!" -Days 7
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Alerts checked" -Percent 100
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo.
echo Technical report: !OUT!
echo Press any key to continue . . .
pause >nul
goto DASHBOARD

:DASH_OPEN_REPORT
start "" notepad.exe "!OUT!"
goto DASHBOARD

:QUICK_DIAG
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
for /f %%I in ('powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%I"
set "OUT=%REPORTS%\Performance_Diagnostics_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Measuring performance" -Percent 20
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\QuickDiagnosis.ps1" -OutFile "!OUT!"
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Diagnostics completed" -Percent 100
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Press any key to continue . . .
pause >nul
goto DASHBOARD

:OPT_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo OPTIMIZE
echo.
echo [1] Gaming Profile - Maximum Performance
echo     Lightweight UI, Game Mode, power and boost settings. Reversible.
echo.
echo [2] Recommended privacy settings
echo     Reduces optional data, advertising and suggestions. Reversible.
echo.
echo [3] Startup and processes
echo     Analyzes startup apps; does not change priorities.
echo.
echo [4] Power
echo     Balanced, High performance or Ultimate Performance.
echo.
echo [5] Back
choice /c 12345 /n /m "Choose: "
if errorlevel 5 goto MAIN
if errorlevel 4 goto POWER_MENU
if errorlevel 3 goto STARTUP_MENU
if errorlevel 2 goto PRIVACY54_MENU
if errorlevel 1 goto GAMING54_MENU
goto OPT_MENU

:GAMING54_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo GAMING PROFILE - MAXIMUM PERFORMANCE
echo.
echo [1] Analyze current status
echo [2] Apply Gaming Profile
echo [3] Restore previous state
echo [4] Open Windows Graphics settings
echo [5] Back
choice /c 12345 /n /m "Choose: "
if errorlevel 5 goto OPT_MENU
if errorlevel 4 goto GAMING54_GRAPHICS
if errorlevel 3 goto GAMING54_RESTORE
if errorlevel 2 goto GAMING54_APPLY
if errorlevel 1 goto GAMING54_ANALYZE
goto GAMING54_MENU

:GAMING54_ANALYZE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\GamingProfileV54.ps1" -Mode Analyze -BackupDir "%BACKUPS%"
echo Press any key to continue . . .
pause >nul
goto GAMING54_MENU

:GAMING54_APPLY
echo.
echo This profile prioritizes responsiveness and performance. It may increase power use and temperatures.
echo It backs up every setting it changes.
choice /c YN /n /m "Apply Gaming Profile? [Y/N]: "
if errorlevel 2 goto GAMING54_MENU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Saving previous state" -Percent 20
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\GamingProfileV54.ps1" -Mode Apply -BackupDir "%BACKUPS%"
set "RC=!errorlevel!"
if not "!RC!"=="0" goto GAMING54_APPLY_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Add -HistoryFile "%HISTORY%" -Action "Gaming Profile" -Detail "Gaming Profile applied with backup."
:GAMING54_APPLY_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Gaming Profile completed" -Percent 100
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Press any key to continue . . .
pause >nul
goto GAMING54_MENU

:GAMING54_RESTORE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\GamingProfileV54.ps1" -Mode Restore -BackupDir "%BACKUPS%"
set "RC=!errorlevel!"
if not "!RC!"=="0" goto GAMING54_RESTORE_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Add -HistoryFile "%HISTORY%" -Action "Restore" -Detail "Gaming Profile restored."
:GAMING54_RESTORE_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Press any key to continue . . .
pause >nul
goto GAMING54_MENU

:GAMING54_GRAPHICS
start "" ms-settings:display-advancedgraphics
goto GAMING54_MENU

:PRIVACY54_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo RECOMMENDED PRIVACY SETTINGS
echo.
echo [1] Analyze status
echo [2] Apply recommended profile
echo [3] Restore previous state
echo [4] Open Windows Privacy settings
echo [5] Back
choice /c 12345 /n /m "Choose: "
if errorlevel 5 goto OPT_MENU
if errorlevel 4 goto PRIVACY54_OPEN
if errorlevel 3 goto PRIVACY54_RESTORE
if errorlevel 2 goto PRIVACY54_APPLY
if errorlevel 1 goto PRIVACY54_ANALYZE
goto PRIVACY54_MENU

:PRIVACY54_ANALYZE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PrivacyV54.ps1" -Mode Analyze -BackupDir "%BACKUPS%"
echo Press any key to continue . . .
pause >nul
goto PRIVACY54_MENU

:PRIVACY54_APPLY
echo.
echo Reduces optional privacy features without disabling Defender, Windows Update, Store or Search.
choice /c YN /n /m "Apply recommended privacy settings? [Y/N]: "
if errorlevel 2 goto PRIVACY54_MENU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PrivacyV54.ps1" -Mode ApplyRecommended -BackupDir "%BACKUPS%"
set "RC=!errorlevel!"
if not "!RC!"=="0" goto PRIVACY54_APPLY_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Add -HistoryFile "%HISTORY%" -Action "Privacy" -Detail "Recommended profile applied with backup."
:PRIVACY54_APPLY_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Press any key to continue . . .
pause >nul
goto PRIVACY54_MENU

:PRIVACY54_RESTORE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PrivacyV54.ps1" -Mode Restore -BackupDir "%BACKUPS%"
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Press any key to continue . . .
pause >nul
goto PRIVACY54_MENU

:PRIVACY54_OPEN
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PrivacyV54.ps1" -Mode OpenSettings -BackupDir "%BACKUPS%"
goto PRIVACY54_MENU

:STARTUP_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo STARTUP AND PROCESSES
echo.
echo [1] Analyze startup apps
echo [2] Open Startup settings
echo [3] Open Task Manager
echo [4] Back
choice /c 1234 /n /m "Choose: "
if errorlevel 4 goto OPT_MENU
if errorlevel 3 goto START_TASKMGR
if errorlevel 2 goto START_SETTINGS
if errorlevel 1 goto STARTUP_SCAN
goto STARTUP_MENU
:START_TASKMGR
start "" taskmgr.exe
goto STARTUP_MENU
:START_SETTINGS
start "" ms-settings:startupapps
goto STARTUP_MENU
:STARTUP_SCAN
for /f %%I in ('powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%I"
set "OUT=%REPORTS%\Startup_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\StartupAnalyze.ps1" -OutFile "!OUT!"
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo WinTool does not disable startup entries automatically.
echo Press any key to continue . . .
pause >nul
goto STARTUP_MENU

:POWER_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo POWER
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PowerPlan.ps1" -Mode Show -BackupFile "%BACKUPS%\PowerPlan.json"
echo.
echo [1] Balanced
echo     Lower power use with dynamic performance.
echo.
echo [2] High performance
echo     Prioritizes performance over power savings.
echo.
echo [3] Ultimate Performance
echo     Minimizes power-saving policies.
echo.
echo [4] Restore previous plan
echo [5] Back
choice /c 12345 /n /m "Choose: "
if errorlevel 5 goto OPT_MENU
if errorlevel 4 goto POWER_RESTORE
if errorlevel 3 goto POWER_MAX
if errorlevel 2 goto POWER_HIGH
if errorlevel 1 goto POWER_BALANCED
goto POWER_MENU

:POWER_BALANCED
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PowerPlan.ps1" -Mode Balanced -BackupFile "%BACKUPS%\PowerPlan.json"
set "RC=!errorlevel!"
if "!RC!"=="0" powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Add -HistoryFile "%HISTORY%" -Action "Power plan" -Detail "Balanced selected."
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Press any key to continue . . .
pause >nul
goto POWER_MENU

:POWER_HIGH
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PowerPlan.ps1" -Mode High -BackupFile "%BACKUPS%\PowerPlan.json"
set "RC=!errorlevel!"
if "!RC!"=="0" powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Add -HistoryFile "%HISTORY%" -Action "Power plan" -Detail "High performance selected."
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Press any key to continue . . .
pause >nul
goto POWER_MENU

:POWER_MAX
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PowerPlan.ps1" -Mode Max -BackupFile "%BACKUPS%\PowerPlan.json"
set "RC=!errorlevel!"
if "!RC!"=="0" powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Add -HistoryFile "%HISTORY%" -Action "Power plan" -Detail "Ultimate Performance selected."
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Press any key to continue . . .
pause >nul
goto POWER_MENU

:POWER_RESTORE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PowerPlan.ps1" -Mode Restore -BackupFile "%BACKUPS%\PowerPlan.json"
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Press any key to continue . . .
pause >nul
goto POWER_MENU

:MAINT_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo SMART MAINTENANCE
echo.
echo [1] Recommended maintenance in one step
echo     Old TEMP files + C: optimization + Windows components only when appropriate.
echo.
echo [2] Analyze maintenance               Read-only
echo [3] Safe cleanup                      Old TEMP + old WER/CrashDumps
echo [4] Regenerable caches                DirectX + thumbnails + Delivery Optimization
echo [5] Empty Recycle Bin                 Always asks first
echo [6] Clean Windows components          DISM StartComponentCleanup
echo [7] Optimize drive C:                 Windows chooses TRIM/appropriate optimization
echo [8] Check VSS / WindowsApps.tmp       Read-only
echo [9] More options / Back
echo.
echo Never touches Minecraft, Downloads, documents, pagefile, WinSxS or WindowsApps.
choice /c 123456789 /n /m "Choose: "
if errorlevel 9 goto MAINT_MORE
if errorlevel 8 goto MAINT_SHADOW
if errorlevel 7 goto MAINT_OPTIMIZE
if errorlevel 6 goto MAINT_COMPONENTS
if errorlevel 5 goto MAINT_RECYCLE
if errorlevel 4 goto MAINT_CACHES
if errorlevel 3 goto MAINT_SAFE
if errorlevel 2 goto MAINT_ANALYZE
if errorlevel 1 goto MAINT_AUTO_MENU
goto MAINT_MENU

:MAINT_AUTO_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo RECOMMENDED MAINTENANCE
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\MaintenanceAutoV54.ps1" -Mode Analyze -ConfigDir "%CONFIG%"
echo.
echo [1] Apply recommended maintenance
echo [2] Back
choice /c 12 /n /m "Choose: "
if errorlevel 2 goto MAINT_MENU
if errorlevel 1 goto MAINT_AUTO_APPLY
goto MAINT_AUTO_MENU

:MAINT_AUTO_APPLY
choice /c YN /n /m "Apply only the actions listed above? [Y/N]: "
if errorlevel 2 goto MAINT_AUTO_MENU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Processing safe maintenance" -Percent 20
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\MaintenanceAutoV54.ps1" -Mode Apply -ConfigDir "%CONFIG%"
set "RC=!errorlevel!"
if not "!RC!"=="0" goto MAINT_AUTO_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Add -HistoryFile "%HISTORY%" -Action "Maintenance" -Detail "Recommended maintenance completed."
:MAINT_AUTO_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Maintenance completed" -Percent 100
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Press any key to continue . . .
pause >nul
goto MAINT_MENU

:MAINT_MORE
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo MAINTENANCE - MORE OPTIONS
echo.
echo [1] Open Storage Sense
echo [2] Open classic Disk Cleanup
echo [3] Back to Maintenance
echo [4] Back to main menu
choice /c 1234 /n /m "Choose: "
if errorlevel 4 goto MAIN
if errorlevel 3 goto MAINT_MENU
if errorlevel 2 goto MAINT_CLEANMGR
if errorlevel 1 goto MAINT_STORAGE_SENSE
goto MAINT_MORE

:MAINT_CLEANMGR
start "" cleanmgr.exe
goto MAINT_MORE

:MAINT_ANALYZE
for /f %%I in ('powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%I"
set "OUT=%REPORTS%\Maintenance_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Analyzing temporary files" -Percent 20
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\MaintenanceV53.ps1" -Mode Analyze -OutFile "!OUT!"
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Analysis completed" -Percent 100
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Report: !OUT!
echo Press any key to continue . . .
pause >nul
goto MAINT_MENU

:MAINT_SAFE
echo.
echo This cleanup only processes old files in TEMP, Windows Temp, WER and CrashDumps.
choice /c YN /n /m "Apply safe cleanup? [Y/N]: "
if errorlevel 2 goto MAINT_MENU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Cleaning old temporary files" -Percent 30
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\MaintenanceV53.ps1" -Mode SafeClean
set "RC=!errorlevel!"
if not "!RC!"=="0" goto MAINT_SAFE_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Add -HistoryFile "%HISTORY%" -Action "Maintenance" -Detail "Safe cleanup of old temporary/report files."
:MAINT_SAFE_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Cleanup completed" -Percent 100
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Press any key to continue . . .
pause >nul
goto MAINT_MENU

:MAINT_CACHES
echo.
echo WARNING:
echo - DirectX Shader Cache will be regenerated.
echo - Temporary stutter may occur while games recompile shaders.
echo - Thumbnails will also be regenerated.
echo - Delivery Optimization is cleared with the Windows cmdlet when available.
choice /c YN /n /m "Clear regenerable caches? [Y/N]: "
if errorlevel 2 goto MAINT_MENU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\MaintenanceV53.ps1" -Mode RegenerableCaches
set "RC=!errorlevel!"
if not "!RC!"=="0" goto MAINT_CACHES_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Add -HistoryFile "%HISTORY%" -Action "Caches" -Detail "Regenerable caches processed."
:MAINT_CACHES_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Press any key to continue . . .
pause >nul
goto MAINT_MENU

:MAINT_RECYCLE
choice /c YN /n /m "Empty the Recycle Bin completely? [Y/N]: "
if errorlevel 2 goto MAINT_MENU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\MaintenanceV53.ps1" -Mode RecycleBin
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Press any key to continue . . .
pause >nul
goto MAINT_MENU

:MAINT_COMPONENTS
echo.
echo Uses DISM /StartComponentCleanup. This may take several minutes.
echo Does not use /ResetBase.
choice /c YN /n /m "Continue? [Y/N]: "
if errorlevel 2 goto MAINT_MENU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\MaintenanceV53.ps1" -Mode ComponentCleanup
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Press any key to continue . . .
pause >nul
goto MAINT_MENU

:MAINT_OPTIMIZE
echo.
echo Windows will use defrag /O to choose the appropriate operation for the drive.
choice /c YN /n /m "Optimize C:? [Y/N]: "
if errorlevel 2 goto MAINT_MENU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\MaintenanceV53.ps1" -Mode OptimizeC
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Press any key to continue . . .
pause >nul
goto MAINT_MENU

:MAINT_SHADOW
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\MaintenanceV53.ps1" -Mode ShadowInfo
echo Press any key to continue . . .
pause >nul
goto MAINT_MENU

:MAINT_STORAGE_SENSE
start "" ms-settings:storagepolicies
goto MAINT_MENU

:TOOLS_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo TOOLS
echo.
echo [1] NETWORK                Ping, jitter, Speedtest, DNS and adapters
echo [2] DRIVERS                Analysis, Windows Update, backup and official support
echo [3] WINDOWS AND REPAIR      DISM, SFC, CHKDSK and diagnostics
echo [4] PERFORMANCE             Background load, baseline and history
echo [5] SOFTWARE               Updates with WinGet
echo [6] ADVANCED TOOLS WinUtil
echo [7] WINDOWS TOOLS   System shortcuts
echo [8] COMPONENTS             Optional dependencies
echo [9] Back
choice /c 123456789 /n /m "Choose: "
if errorlevel 9 goto MAIN
if errorlevel 8 goto COMPONENTS_MENU
if errorlevel 7 goto WINDOWS_TOOLS
if errorlevel 6 goto ADVANCED_TOOLS
if errorlevel 5 goto SOFTWARE_MENU
if errorlevel 4 goto PERF_MENU
if errorlevel 3 goto REPAIR_MENU
if errorlevel 2 goto DRIVER_MENU
if errorlevel 1 goto NETWORK_MENU
goto TOOLS_MENU

:NETWORK_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo NETWORK
echo.
echo [1] Quick diagnostics
echo [2] Ping / packet loss / jitter
echo [3] Speedtest Ookla
echo [4] DNS: compare / change / restore
echo [5] Traceroute to 1.1.1.1
echo [6] Adapter information
echo [7] Back to Tools
choice /c 1234567 /n /m "Choose: "
if errorlevel 7 goto TOOLS_MENU
if errorlevel 6 goto NET_ADAPTER
if errorlevel 5 goto NET_TRACE
if errorlevel 4 goto DNS_MENU
if errorlevel 3 goto SPEEDTEST
if errorlevel 2 goto PINGTEST
if errorlevel 1 goto NET_QUICK
goto NETWORK_MENU

:NET_QUICK
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\NetworkQuick.ps1"
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Press any key to continue . . .
pause >nul
goto NETWORK_MENU
:NET_ADAPTER
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\NetAdapterInfo.ps1"
echo Press any key to continue . . .
pause >nul
goto NETWORK_MENU
:NET_TRACE
tracert -d 1.1.1.1
echo Press any key to continue . . .
pause >nul
goto NETWORK_MENU
:PINGTEST
for /f %%I in ('powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%I"
set "OUT=%REPORTS%\Ping_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PingTest.ps1" -OutFile "!OUT!"
set "RC=!errorlevel!"
if exist "!OUT!" type "!OUT!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Press any key to continue . . .
pause >nul
goto NETWORK_MENU
:SPEEDTEST
for /f %%I in ('powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%I"
set "OUT=%REPORTS%\Speedtest_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\SpeedTestManager.ps1" -OutFile "!OUT!"
set "RC=!errorlevel!"
if exist "!OUT!" type "!OUT!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Press any key to continue . . .
pause >nul
goto NETWORK_MENU

:DNS_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo DNS
echo.
echo [1] Comparar Cloudflare / Google / Quad9
echo [2] Cloudflare 1.1.1.1
echo [3] Google 8.8.8.8
echo [4] Quad9 9.9.9.9
echo [5] Automatico / DHCP
echo [6] Restore backup
echo [7] Back to Network
choice /c 1234567 /n /m "Choose: "
if errorlevel 7 goto NETWORK_MENU
if errorlevel 6 goto DNS_RESTORE
if errorlevel 5 goto DNS_AUTO
if errorlevel 4 goto DNS_QUAD9
if errorlevel 3 goto DNS_GOOGLE
if errorlevel 2 goto DNS_CLOUDFLARE
if errorlevel 1 goto DNS_BENCH
goto DNS_MENU

:DNS_BENCH
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DnsBench.ps1"
echo Press any key to continue . . .
pause >nul
goto DNS_MENU
:DNS_CLOUDFLARE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DnsManager.ps1" -Mode Cloudflare -BackupFile "%BACKUPS%\DNS.json"
echo Press any key to continue . . .
pause >nul
goto DNS_MENU
:DNS_GOOGLE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DnsManager.ps1" -Mode Google -BackupFile "%BACKUPS%\DNS.json"
echo Press any key to continue . . .
pause >nul
goto DNS_MENU
:DNS_QUAD9
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DnsManager.ps1" -Mode Quad9 -BackupFile "%BACKUPS%\DNS.json"
echo Press any key to continue . . .
pause >nul
goto DNS_MENU
:DNS_AUTO
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DnsManager.ps1" -Mode Automatic -BackupFile "%BACKUPS%\DNS.json"
echo Press any key to continue . . .
pause >nul
goto DNS_MENU
:DNS_RESTORE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DnsManager.ps1" -Mode Restore -BackupFile "%BACKUPS%\DNS.json"
echo Press any key to continue . . .
pause >nul
goto DNS_MENU

:DRIVER_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo DRIVERS
echo.
echo [1] Analyze hardware and drivers
echo [2] Find drivers with Windows Update
echo [3] Back up installed drivers
echo [4] Open detected official support
echo [5] BIOS / motherboard - information only
echo [6] Back
choice /c 123456 /n /m "Choose: "
if errorlevel 6 goto TOOLS_MENU
if errorlevel 5 goto DRIVER_BIOS
if errorlevel 4 goto DRIVER_OFFICIAL
if errorlevel 3 goto DRIVER_BACKUP
if errorlevel 2 goto DRIVER_WU
if errorlevel 1 goto DRIVER_SCAN
goto DRIVER_MENU
:DRIVER_SCAN
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DriverManagerV5.ps1" -Mode Scan -BackupDir "%BACKUPS%"
echo Press any key to continue . . .
pause >nul
goto DRIVER_MENU
:DRIVER_WU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DriverManagerV5.ps1" -Mode WindowsUpdate -BackupDir "%BACKUPS%"
echo Press any key to continue . . .
pause >nul
goto DRIVER_MENU
:DRIVER_BACKUP
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DriverManagerV5.ps1" -Mode Backup -BackupDir "%BACKUPS%"
echo Press any key to continue . . .
pause >nul
goto DRIVER_MENU
:DRIVER_OFFICIAL
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DriverManagerV5.ps1" -Mode Official -BackupDir "%BACKUPS%"
echo Press any key to continue . . .
pause >nul
goto DRIVER_MENU
:DRIVER_BIOS
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DriverManagerV5.ps1" -Mode BIOS -BackupDir "%BACKUPS%"
echo Press any key to continue . . .
pause >nul
goto DRIVER_MENU

:REPAIR_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo WINDOWS AND REPAIR
echo.
echo [1] Repair diagnostics
echo [2] DISM RestoreHealth
echo [3] SFC /scannow
echo [4] CHKDSK /scan C:
echo [5] Basic network repair
echo [6] Diagnosticar WinGet
echo [7] Back
choice /c 1234567 /n /m "Choose: "
if errorlevel 7 goto TOOLS_MENU
if errorlevel 6 goto REPAIR_WINGET
if errorlevel 5 goto REPAIR_NETWORK
if errorlevel 4 goto RUN_CHKDSK
if errorlevel 3 goto REPAIR_SFC
if errorlevel 2 goto REPAIR_DISM
if errorlevel 1 goto REPAIR_CHECK
goto REPAIR_MENU
:REPAIR_CHECK
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\RepairCenter.ps1" -Mode Check
echo Press any key to continue . . .
pause >nul
goto REPAIR_MENU
:REPAIR_DISM
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\RepairCenter.ps1" -Mode DISM
echo Press any key to continue . . .
pause >nul
goto REPAIR_MENU
:REPAIR_SFC
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\RepairCenter.ps1" -Mode SFC
echo Press any key to continue . . .
pause >nul
goto REPAIR_MENU
:REPAIR_NETWORK
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\RepairCenter.ps1" -Mode Network
echo Press any key to continue . . .
pause >nul
goto REPAIR_MENU
:REPAIR_WINGET
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\RepairCenter.ps1" -Mode WinGet
echo Press any key to continue . . .
pause >nul
goto REPAIR_MENU
:RUN_CHKDSK
chkdsk C: /scan
echo Press any key to continue . . .
pause >nul
goto REPAIR_MENU

:PERF_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo PERFORMANCE
echo.
echo [1] What is slowing down my PC?
echo [2] Analyze background load - 30 s
echo [3] Measure BEFORE / AFTER
echo [4] Create baseline
echo [5] Comparar baseline
echo [6] Check pending restart
echo [7] WinTool change history
echo [8] Back
choice /c 12345678 /n /m "Choose: "
if errorlevel 8 goto TOOLS_MENU
if errorlevel 7 goto SHOW_HISTORY
if errorlevel 6 goto PERF_REBOOT
if errorlevel 5 goto BASELINE_COMPARE
if errorlevel 4 goto BASELINE_CREATE
if errorlevel 3 goto BEFORE_AFTER_MENU
if errorlevel 2 goto BGSCAN
if errorlevel 1 goto QUICK_DIAG
goto PERF_MENU
:BEFORE_AFTER_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo MEASURE BEFORE / AFTER
echo.
echo Helps verify real changes without promising FPS gains.
echo Run both measurements with similar programs and conditions.
echo.
echo [1] Save BEFORE measurement
echo [2] Save AFTER measurement and compare
echo [3] Mostrar ultima comparacion
echo [4] Back
choice /c 1234 /n /m "Choose: "
if errorlevel 4 goto PERF_MENU
if errorlevel 3 goto BEFORE_AFTER_SHOW
if errorlevel 2 goto BEFORE_AFTER_AFTER
if errorlevel 1 goto BEFORE_AFTER_BEFORE
goto BEFORE_AFTER_MENU

:BEFORE_AFTER_BEFORE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\BeforeAfterV54.ps1" -Mode Before -DataFile "%BACKUPS%\AntesDespuesV54.json"
echo Press any key to continue . . .
pause >nul
goto BEFORE_AFTER_MENU

:BEFORE_AFTER_AFTER
for /f %%I in ('powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%I"
set "OUT=%REPORTS%\Antes_Despues_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\BeforeAfterV54.ps1" -Mode After -DataFile "%BACKUPS%\AntesDespuesV54.json" -OutFile "!OUT!"
echo Press any key to continue . . .
pause >nul
goto BEFORE_AFTER_MENU

:BEFORE_AFTER_SHOW
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\BeforeAfterV54.ps1" -Mode Show -DataFile "%BACKUPS%\AntesDespuesV54.json"
echo Press any key to continue . . .
pause >nul
goto BEFORE_AFTER_MENU

:SHOW_HISTORY
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Show -HistoryFile "%HISTORY%"
echo Press any key to continue . . .
pause >nul
goto PERF_MENU
:BGSCAN
for /f %%I in ('powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%I"
set "OUT=%REPORTS%\Background_Load_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\BackgroundAnalyzer.ps1" -OutFile "!OUT!" -Seconds 30
if exist "!OUT!" type "!OUT!"
echo Press any key to continue . . .
pause >nul
goto PERF_MENU
:PERF_REBOOT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PendingReboot.ps1"
echo Press any key to continue . . .
pause >nul
goto PERF_MENU
:BASELINE_CREATE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\BaselineV5.ps1" -Mode Create -DataFile "%BACKUPS%\BaselineV5.json" -ReportsDir "%REPORTS%"
echo Press any key to continue . . .
pause >nul
goto PERF_MENU
:BASELINE_COMPARE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\BaselineV5.ps1" -Mode Compare -DataFile "%BACKUPS%\BaselineV5.json" -ReportsDir "%REPORTS%"
echo Press any key to continue . . .
pause >nul
goto PERF_MENU

:SOFTWARE_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo SOFTWARE / WINGET
echo.
echo [1] Check for updates
echo [2] Update all applicable packages
echo [3] Open Installed apps
echo [4] Back
choice /c 1234 /n /m "Choose: "
if errorlevel 4 goto TOOLS_MENU
if errorlevel 3 goto SOFTWARE_INSTALLED
if errorlevel 2 goto SOFTWARE_UPGRADE
if errorlevel 1 goto SOFTWARE_CHECK
goto SOFTWARE_MENU
:SOFTWARE_INSTALLED
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\SoftwareCenter.ps1" -Mode OpenInstalled
goto SOFTWARE_MENU
:SOFTWARE_CHECK
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\SoftwareCenter.ps1" -Mode Check
echo Press any key to continue . . .
pause >nul
goto SOFTWARE_MENU
:SOFTWARE_UPGRADE
echo This option may update several applications.
choice /c YN /n /m "Continue with winget upgrade --all? [Y/N]: "
if errorlevel 2 goto SOFTWARE_MENU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\SoftwareCenter.ps1" -Mode UpgradeAll
echo Press any key to continue . . .
pause >nul
goto SOFTWARE_MENU

:ADVANCED_TOOLS
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo ADVANCED TOOLS
echo.
echo [1] WinUtil - Chris Titus Tech
echo [2] Back
choice /c 12 /n /m "Choose: "
if errorlevel 2 goto TOOLS_MENU
if errorlevel 1 goto OPEN_WINUTIL
goto ADVANCED_TOOLS
:OPEN_WINUTIL
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinUtilLauncher.ps1"
echo Press any key to continue . . .
pause >nul
goto ADVANCED_TOOLS

:WINDOWS_TOOLS
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo WINDOWS TOOLS
echo.
echo [1] Task Manager
echo [2] Resource Monitor
echo [3] Event Viewer
echo [4] Device Manager
echo [5] Disk Management
echo [6] Task Scheduler
echo [7] Performance Monitor
echo [8] System Information
echo [9] Back
choice /c 123456789 /n /m "Choose: "
if errorlevel 9 goto TOOLS_MENU
if errorlevel 8 goto OPEN_MSINFO
if errorlevel 7 goto OPEN_PERFMON
if errorlevel 6 goto OPEN_TASKSCHD
if errorlevel 5 goto OPEN_DISKMGMT
if errorlevel 4 goto OPEN_DEVMGMT
if errorlevel 3 goto OPEN_EVENTVWR
if errorlevel 2 goto OPEN_RESMON
if errorlevel 1 goto OPEN_TASKMGR
goto WINDOWS_TOOLS
:OPEN_MSINFO
start "" msinfo32.exe
goto WINDOWS_TOOLS
:OPEN_PERFMON
start "" perfmon.exe
goto WINDOWS_TOOLS
:OPEN_TASKSCHD
start "" taskschd.msc
goto WINDOWS_TOOLS
:OPEN_DISKMGMT
start "" diskmgmt.msc
goto WINDOWS_TOOLS
:OPEN_DEVMGMT
start "" devmgmt.msc
goto WINDOWS_TOOLS
:OPEN_EVENTVWR
start "" eventvwr.msc
goto WINDOWS_TOOLS
:OPEN_RESMON
start "" resmon.exe
goto WINDOWS_TOOLS
:OPEN_TASKMGR
start "" taskmgr.exe
goto WINDOWS_TOOLS

:COMPONENTS_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\Components.ps1"
echo.
echo [1] Install Ookla Speedtest CLI with WinGet
echo [2] Open Microsoft Store - App Installer / WinGet
echo [3] Back
choice /c 123 /n /m "Choose: "
if errorlevel 3 goto TOOLS_MENU
if errorlevel 2 goto OPEN_APPINSTALLER
if errorlevel 1 goto INSTALL_SPEEDTEST
goto COMPONENTS_MENU
:OPEN_APPINSTALLER
start "" "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
goto COMPONENTS_MENU
:INSTALL_SPEEDTEST
where winget >nul 2>&1
if not errorlevel 1 goto INSTALL_SPEEDTEST_OK
echo [ERROR] WinGet is not available.
echo Press any key to continue . . .
pause >nul
goto COMPONENTS_MENU
:INSTALL_SPEEDTEST_OK
choice /c YN /n /m "Install the official Speedtest CLI through WinGet? [Y/N]: "
if errorlevel 2 goto COMPONENTS_MENU
winget install --id Ookla.Speedtest.CLI -e --accept-source-agreements --accept-package-agreements
echo Press any key to continue . . .
pause >nul
goto COMPONENTS_MENU

:ANALYZE_GENERAL
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
for /f %%I in ('powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%I"
set "OUT=%REPORTS%\General_Analysis_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\AnalyzeGeneral.ps1" -OutFile "!OUT!"
if exist "!OUT!" type "!OUT!"
echo Press any key to continue . . .
pause >nul
goto DASHBOARD

:ANALYZE_ADV
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo ADVANCED ANALYSIS
echo Includes DISM ScanHealth, SFC verifyonly, CHKDSK /scan C: and recent events.
echo This may take several minutes. It does not use CHKDSK /R.
choice /c YN /n /m "Comenzar? [Y/N]: "
if errorlevel 2 goto DASHBOARD
for /f %%I in ('powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%I"
set "OUT=%REPORTS%\Advanced_Analysis_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\AnalyzeAdvanced.ps1" -OutFile "!OUT!"
echo Report: !OUT!
echo Press any key to continue . . .
pause >nul
goto DASHBOARD

:CONFIG_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo SETTINGS / RESTORE
echo.
echo [1] WinTool change history
echo [2] Restore Gaming Profile
echo [3] Restore Privacy settings
echo [4] Restore DNS
echo [5] Restore power plan
echo [6] Open BACKUPS
echo [7] Open REPORTS
echo [8] Information / security
echo [9] Back
choice /c 123456789 /n /m "Choose: "
if errorlevel 9 goto MAIN
if errorlevel 8 goto ABOUT
if errorlevel 7 goto OPEN_REPORTS
if errorlevel 6 goto OPEN_BACKUPS
if errorlevel 5 goto RESTORE_POWER
if errorlevel 4 goto RESTORE_DNS
if errorlevel 3 goto RESTORE_PRIVACY54
if errorlevel 2 goto RESTORE_GAMING54
if errorlevel 1 goto CONFIG_HISTORY
goto CONFIG_MENU

:CONFIG_HISTORY
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Show -HistoryFile "%HISTORY%"
echo Press any key to continue . . .
pause >nul
goto CONFIG_MENU

:OPEN_BACKUPS
start "" "%BACKUPS%"
goto CONFIG_MENU

:OPEN_REPORTS
start "" "%REPORTS%"
goto CONFIG_MENU

:RESTORE_GAMING54
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\GamingProfileV54.ps1" -Mode Restore -BackupDir "%BACKUPS%"
echo Press any key to continue . . .
pause >nul
goto CONFIG_MENU

:RESTORE_PRIVACY54
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PrivacyV54.ps1" -Mode Restore -BackupDir "%BACKUPS%"
echo Press any key to continue . . .
pause >nul
goto CONFIG_MENU

:RESTORE_POWER
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PowerPlan.ps1" -Mode Restore -BackupFile "%BACKUPS%\PowerPlan.json"
echo Press any key to continue . . .
pause >nul
goto CONFIG_MENU

:RESTORE_DNS
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DnsManager.ps1" -Mode Restore -BackupFile "%BACKUPS%\DNS.json"
echo Press any key to continue . . .
pause >nul
goto CONFIG_MENU

:ABOUT
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo WinTool V!VERSION! brings diagnostics, maintenance, optimization and tools into a simple interface.
echo.
echo BUILD V!VERSION!:
echo - hardened engine: paths, permissions, Windows x64 and components verified;
echo - WinAnalyzer detects possible FPS limits / VSync;
echo - new temporary OPTIMIZE GAME feature that respects existing settings;
echo - simple results: average FPS, 1%% Low, minimum FPS, smoothness, CPU, GPU and RAM;
echo - Advanced data kept separate to keep the main screen simple;
echo - new analysis: WHAT IS SLOWING DOWN MY GAME;
echo - Gaming Profile recommendation and access when it is not active;
echo - disk activity and additional CPU load added to gaming analysis;
echo - compatibility with tests saved by V5.6.
echo.
echo WinAnalyzer continues to use integrated PresentMon 2.5.1 for FPS and frametimes.
echo.
echo WINTOOL DATA:
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\StoragePathsV541.ps1" -Mode Show -BaseDir "%BASE%" -ConfigFile "%BOOTCONFIG%\StorageMode.json"
echo Press any key to continue . . .
pause >nul
goto CONFIG_MENU

:STORAGE_FAIL
cls
echo [ERROR] WinTool could not prepare its working folders.
echo.
echo WinTool V!VERSION! uses %%LOCALAPPDATA%%\WinTool for REPORTS, BACKUPS and LOGS.
echo This avoids conflicts with protected Desktop/Documents folders.
echo.
echo Do not disable Windows Security or add cmd.exe as a global exclusion.
echo Press any key to continue . . .
pause >nul
goto END

:END
endlocal
exit /b
