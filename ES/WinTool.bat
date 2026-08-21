@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
chcp 65001 >nul 2>&1
color 0B
mode con cols=100 lines=40 >nul 2>&1

set "BASE=%~dp0"
set "TOOLS=%BASE%TOOLS"
set "VERSION=DESCONOCIDA"
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
echo WinTool necesita permisos de administrador para diagnosticos y mantenimiento del sistema.
echo Solicitando permiso...
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

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\SelfTest.ps1" -ToolsDir "%TOOLS%" -LogFile "%LOGS%\SelfTest_Ultimo.txt" -ReportsDir "%REPORTS%" -BackupsDir "%BACKUPS%" -ConfigDir "%CONFIG%" -PresentMonPath "%PRESENTMON%" -BatFile "%~f0"
if not "%errorlevel%"=="0" goto SELFTEST_FAIL

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo Preparando entorno...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Comprobando Windows" -Percent 20
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Verificando scripts" -Percent 40
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Preparando reportes y backups" -Percent 60
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Comprobando conectividad" -Percent 80
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Cargando WinTool" -Percent 100
timeout /t 1 /nobreak >nul
goto MAIN

:SELFTEST_FAIL
echo.
echo [ERROR] WinTool detecto un problema antes de iniciar.
echo Revisa: %LOGS%\SelfTest_Ultimo.txt
pause
goto END

:MAIN
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
set "NET=DESCONOCIDO"
set "REBOOT=DESCONOCIDO"
for /f "tokens=1-2 delims=|" %%A in ('powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\StartupStatus.ps1" 2^>nul') do (
    if "%%A"=="INTERNET" set "NET=%%B"
    if "%%A"=="REBOOT" set "REBOOT=%%B"
)
echo Estado rapido: Internet !NET! ^| Reinicio pendiente !REBOOT!
echo.
echo [1] ESTADO DE MI PC              Panel rapido, diagnostico y alertas
echo [2] OPTIMIZAR                    Cambios seleccionados y reversibles
echo [3] MANTENIMIENTO INTELIGENTE    Analiza, limpia y mantiene de forma controlada
echo [4] HERRAMIENTAS                 Red, drivers, reparacion, software y rendimiento
echo [5] CONFIGURACION / RESTAURAR    Backups, historial, reportes y reversion
echo [6] WinAnalyzer V1.0             FPS, fluidez y cuello de botella
echo.
echo [0] SALIR
echo.
choice /c 1234560 /n /m "Elegir: "
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
set "PMSTATUS=DESCONOCIDO"
for /f "tokens=1-2 delims=|" %%A in ('powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinAnalyzerCheckV10.ps1" -PresentMonPath "%PRESENTMON%"') do (
    if "%%A"=="PRESENTMON" set "PMSTATUS=%%B"
)
echo PresentMon.............. !PMSTATUS!
echo.
echo [1] ANALIZAR MI JUEGO
echo     Test de FPS, fluidez y cuello de botella
echo.
echo [2] ULTIMA PRUEBA
echo [3] HISTORIAL
echo [4] COMO FUNCIONA
echo [5] COMPONENTES
echo [6] VOLVER A WINTOOL
choice /c 123456 /n /m "Elegir: "
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
pause
goto WINANALYZER_MENU

:WINANALYZER_LAST
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinAnalyzerV10.ps1" -Mode Last -PresentMonPath "%PRESENTMON%" -ReportsRoot "%REPORTS%" -ConfigDir "%CONFIG%" -BackupsDir "%BACKUPS%" -ToolsDir "%TOOLS%" -UiScript "%TOOLS%\WinAnalyzerUIV1.ps1"
pause
goto WINANALYZER_MENU

:WINANALYZER_HISTORY
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinAnalyzerUIV1.ps1" -Mode Header
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinAnalyzerV10.ps1" -Mode History -PresentMonPath "%PRESENTMON%" -ReportsRoot "%REPORTS%" -ConfigDir "%CONFIG%" -BackupsDir "%BACKUPS%" -ToolsDir "%TOOLS%" -UiScript "%TOOLS%\WinAnalyzerUIV1.ps1"
pause
goto WINANALYZER_MENU

:WINANALYZER_INFO
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinAnalyzerUIV1.ps1" -Mode Header
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinAnalyzerV10.ps1" -Mode Info -PresentMonPath "%PRESENTMON%" -ReportsRoot "%REPORTS%" -ConfigDir "%CONFIG%" -BackupsDir "%BACKUPS%" -ToolsDir "%TOOLS%" -UiScript "%TOOLS%\WinAnalyzerUIV1.ps1"
pause
goto WINANALYZER_MENU

:WINANALYZER_COMPONENT
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinAnalyzerUIV1.ps1" -Mode Header
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinAnalyzerV10.ps1" -Mode Component -PresentMonPath "%PRESENTMON%" -ReportsRoot "%REPORTS%" -ConfigDir "%CONFIG%" -BackupsDir "%BACKUPS%" -ToolsDir "%TOOLS%" -UiScript "%TOOLS%\WinAnalyzerUIV1.ps1"
echo.
echo Licencia: %BUNDLED%\PresentMon\LICENSE.txt
pause
goto WINANALYZER_MENU

:DASHBOARD
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
for /f %%I in ('powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%I"
set "OUT=%REPORTS%\Estado_PC_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Leyendo hardware" -Percent 20
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\Dashboard.ps1" -OutFile "!OUT!"
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Panel actualizado" -Percent 100
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo.
echo [1] Alertas inteligentes
echo     Traduce eventos de Windows a avisos simples y separa INFO de errores reales.
echo [2] Que esta ralentizando mi PC?
echo [3] Analisis general
echo [4] Analisis avanzado
echo [5] Abrir ultimo reporte
echo [6] Volver
choice /c 123456 /n /m "Elegir: "
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
set "OUT=%REPORTS%\Alertas_Inteligentes_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Revisando eventos importantes" -Percent 25
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\SmartAlertsV55.ps1" -OutFile "!OUT!" -Days 7
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Alertas revisadas" -Percent 100
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo.
echo Reporte tecnico: !OUT!
pause
goto DASHBOARD

:DASH_OPEN_REPORT
start "" notepad.exe "!OUT!"
goto DASHBOARD

:QUICK_DIAG
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
for /f %%I in ('powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%I"
set "OUT=%REPORTS%\Diagnostico_Rendimiento_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Midiendo rendimiento" -Percent 20
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\QuickDiagnosis.ps1" -OutFile "!OUT!"
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Diagnostico completado" -Percent 100
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
pause
goto DASHBOARD

:OPT_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo OPTIMIZAR
echo.
echo [1] Perfil Gaming - Maximo rendimiento
echo     Interfaz ligera, Game Mode, energia y boost. Reversible.
echo.
echo [2] Privacidad recomendada
echo     Reduce datos opcionales, publicidad y sugerencias. Reversible.
echo.
echo [3] Inicio y procesos
echo     Analiza programas de inicio; no cambia prioridades.
echo.
echo [4] Energia
echo     Equilibrado, Alto rendimiento o Maximo rendimiento.
echo.
echo [5] Volver
choice /c 12345 /n /m "Elegir: "
if errorlevel 5 goto MAIN
if errorlevel 4 goto POWER_MENU
if errorlevel 3 goto STARTUP_MENU
if errorlevel 2 goto PRIVACY54_MENU
if errorlevel 1 goto GAMING54_MENU
goto OPT_MENU

:GAMING54_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo PERFIL GAMING - MAXIMO RENDIMIENTO
echo.
echo [1] Analizar estado actual
echo [2] Aplicar perfil Gaming
echo [3] Restaurar estado anterior
echo [4] Abrir configuracion de Graficos de Windows
echo [5] Volver
choice /c 12345 /n /m "Elegir: "
if errorlevel 5 goto OPT_MENU
if errorlevel 4 goto GAMING54_GRAPHICS
if errorlevel 3 goto GAMING54_RESTORE
if errorlevel 2 goto GAMING54_APPLY
if errorlevel 1 goto GAMING54_ANALYZE
goto GAMING54_MENU

:GAMING54_ANALYZE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\GamingProfileV54.ps1" -Mode Analyze -BackupDir "%BACKUPS%"
pause
goto GAMING54_MENU

:GAMING54_APPLY
echo.
echo Este perfil prioriza respuesta y rendimiento. Puede aumentar consumo y temperatura.
echo Crea backup de cada ajuste que modifica.
choice /c SN /n /m "Aplicar Perfil Gaming? [S/N]: "
if errorlevel 2 goto GAMING54_MENU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Guardando estado anterior" -Percent 20
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\GamingProfileV54.ps1" -Mode Apply -BackupDir "%BACKUPS%"
set "RC=!errorlevel!"
if not "!RC!"=="0" goto GAMING54_APPLY_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Add -HistoryFile "%HISTORY%" -Action "Perfil Gaming" -Detail "Perfil Gaming aplicado con backup."
:GAMING54_APPLY_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Perfil Gaming finalizado" -Percent 100
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
pause
goto GAMING54_MENU

:GAMING54_RESTORE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\GamingProfileV54.ps1" -Mode Restore -BackupDir "%BACKUPS%"
set "RC=!errorlevel!"
if not "!RC!"=="0" goto GAMING54_RESTORE_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Add -HistoryFile "%HISTORY%" -Action "Restauracion" -Detail "Perfil Gaming restaurado."
:GAMING54_RESTORE_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
pause
goto GAMING54_MENU

:GAMING54_GRAPHICS
start "" ms-settings:display-advancedgraphics
goto GAMING54_MENU

:PRIVACY54_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo PRIVACIDAD RECOMENDADA
echo.
echo [1] Analizar estado
echo [2] Aplicar perfil recomendado
echo [3] Restaurar estado anterior
echo [4] Abrir Privacidad de Windows
echo [5] Volver
choice /c 12345 /n /m "Elegir: "
if errorlevel 5 goto OPT_MENU
if errorlevel 4 goto PRIVACY54_OPEN
if errorlevel 3 goto PRIVACY54_RESTORE
if errorlevel 2 goto PRIVACY54_APPLY
if errorlevel 1 goto PRIVACY54_ANALYZE
goto PRIVACY54_MENU

:PRIVACY54_ANALYZE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PrivacyV54.ps1" -Mode Analyze -BackupDir "%BACKUPS%"
pause
goto PRIVACY54_MENU

:PRIVACY54_APPLY
echo.
echo Reduce opciones opcionales de privacidad sin desactivar Defender, Update, Store ni Buscar.
choice /c SN /n /m "Aplicar privacidad recomendada? [S/N]: "
if errorlevel 2 goto PRIVACY54_MENU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PrivacyV54.ps1" -Mode ApplyRecommended -BackupDir "%BACKUPS%"
set "RC=!errorlevel!"
if not "!RC!"=="0" goto PRIVACY54_APPLY_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Add -HistoryFile "%HISTORY%" -Action "Privacidad" -Detail "Perfil recomendado aplicado con backup."
:PRIVACY54_APPLY_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
pause
goto PRIVACY54_MENU

:PRIVACY54_RESTORE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PrivacyV54.ps1" -Mode Restore -BackupDir "%BACKUPS%"
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
pause
goto PRIVACY54_MENU

:PRIVACY54_OPEN
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PrivacyV54.ps1" -Mode OpenSettings -BackupDir "%BACKUPS%"
goto PRIVACY54_MENU

:STARTUP_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo INICIO Y PROCESOS
echo.
echo [1] Analizar programas de inicio
echo [2] Abrir configuracion de Inicio
echo [3] Abrir Administrador de tareas
echo [4] Volver
choice /c 1234 /n /m "Elegir: "
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
set "OUT=%REPORTS%\Inicio_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\StartupAnalyze.ps1" -OutFile "!OUT!"
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo WinTool no deshabilita entradas automaticamente.
pause
goto STARTUP_MENU

:POWER_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo ENERGIA
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PowerPlan.ps1" -Mode Show -BackupFile "%BACKUPS%\PowerPlan.json"
echo.
echo [1] Equilibrado
echo     Menor consumo y rendimiento dinamico.
echo.
echo [2] Alto rendimiento
echo     Prioriza rendimiento sobre ahorro.
echo.
echo [3] Maximo rendimiento
echo     Reduce al minimo las politicas de ahorro.
echo.
echo [4] Restaurar plan anterior
echo [5] Volver
choice /c 12345 /n /m "Elegir: "
if errorlevel 5 goto OPT_MENU
if errorlevel 4 goto POWER_RESTORE
if errorlevel 3 goto POWER_MAX
if errorlevel 2 goto POWER_HIGH
if errorlevel 1 goto POWER_BALANCED
goto POWER_MENU

:POWER_BALANCED
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PowerPlan.ps1" -Mode Balanced -BackupFile "%BACKUPS%\PowerPlan.json"
set "RC=!errorlevel!"
if "!RC!"=="0" powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Add -HistoryFile "%HISTORY%" -Action "Plan de energia" -Detail "Equilibrado seleccionado."
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
pause
goto POWER_MENU

:POWER_HIGH
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PowerPlan.ps1" -Mode High -BackupFile "%BACKUPS%\PowerPlan.json"
set "RC=!errorlevel!"
if "!RC!"=="0" powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Add -HistoryFile "%HISTORY%" -Action "Plan de energia" -Detail "Alto rendimiento seleccionado."
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
pause
goto POWER_MENU

:POWER_MAX
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PowerPlan.ps1" -Mode Max -BackupFile "%BACKUPS%\PowerPlan.json"
set "RC=!errorlevel!"
if "!RC!"=="0" powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Add -HistoryFile "%HISTORY%" -Action "Plan de energia" -Detail "Maximo rendimiento seleccionado."
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
pause
goto POWER_MENU

:POWER_RESTORE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PowerPlan.ps1" -Mode Restore -BackupFile "%BACKUPS%\PowerPlan.json"
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
pause
goto POWER_MENU

:MAINT_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo MANTENIMIENTO INTELIGENTE
echo.
echo [1] Mantenimiento recomendado en 1 paso
echo     TEMP antiguo + optimizacion C: + componentes Windows solo cuando corresponde.
echo.
echo [2] Analizar mantenimiento             Solo lectura
echo [3] Limpieza segura                    TEMP viejo + WER/CrashDumps viejos
echo [4] Caches regenerables                DirectX + miniaturas + Delivery Optimization
echo [5] Vaciar papelera                    Siempre pregunta antes
echo [6] Limpiar componentes Windows        DISM StartComponentCleanup
echo [7] Optimizar unidad C:                Windows elige TRIM/optimizacion adecuada
echo [8] Revisar VSS / WindowsApps.tmp      Solo lectura
echo [9] Mas opciones / Volver
echo.
echo Nunca toca Minecraft, Descargas, documentos, pagefile, WinSxS ni WindowsApps.
choice /c 123456789 /n /m "Elegir: "
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
echo MANTENIMIENTO RECOMENDADO
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\MaintenanceAutoV54.ps1" -Mode Analyze -ConfigDir "%CONFIG%"
echo.
echo [1] Aplicar mantenimiento recomendado
echo [2] Volver
choice /c 12 /n /m "Elegir: "
if errorlevel 2 goto MAINT_MENU
if errorlevel 1 goto MAINT_AUTO_APPLY
goto MAINT_AUTO_MENU

:MAINT_AUTO_APPLY
choice /c SN /n /m "Aplicar solo las acciones indicadas arriba? [S/N]: "
if errorlevel 2 goto MAINT_AUTO_MENU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Procesando mantenimiento seguro" -Percent 20
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\MaintenanceAutoV54.ps1" -Mode Apply -ConfigDir "%CONFIG%"
set "RC=!errorlevel!"
if not "!RC!"=="0" goto MAINT_AUTO_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Add -HistoryFile "%HISTORY%" -Action "Mantenimiento" -Detail "Mantenimiento recomendado ejecutado."
:MAINT_AUTO_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Mantenimiento finalizado" -Percent 100
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
pause
goto MAINT_MENU

:MAINT_MORE
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo MANTENIMIENTO - MAS OPCIONES
echo.
echo [1] Abrir Sensor de almacenamiento
echo [2] Abrir Liberador de espacio clasico
echo [3] Volver a Mantenimiento
echo [4] Volver al menu principal
choice /c 1234 /n /m "Elegir: "
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
set "OUT=%REPORTS%\Mantenimiento_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Analizando temporales" -Percent 20
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\MaintenanceV53.ps1" -Mode Analyze -OutFile "!OUT!"
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Analisis completado" -Percent 100
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
echo Reporte: !OUT!
pause
goto MAINT_MENU

:MAINT_SAFE
echo.
echo Esta limpieza solo procesa archivos antiguos en TEMP, Windows Temp, WER y CrashDumps.
choice /c SN /n /m "Aplicar limpieza segura? [S/N]: "
if errorlevel 2 goto MAINT_MENU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Limpiando temporales antiguos" -Percent 30
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\MaintenanceV53.ps1" -Mode SafeClean
set "RC=!errorlevel!"
if not "!RC!"=="0" goto MAINT_SAFE_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Add -HistoryFile "%HISTORY%" -Action "Mantenimiento" -Detail "Limpieza segura de temporales/reportes antiguos."
:MAINT_SAFE_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Progress -Label "Limpieza finalizada" -Percent 100
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
pause
goto MAINT_MENU

:MAINT_CACHES
echo.
echo ADVERTENCIA:
echo - DirectX Shader Cache se regenerara.
echo - Puede haber stutter temporal mientras los juegos recompilan shaders.
echo - Miniaturas tambien se regeneran.
echo - Delivery Optimization se vacia mediante el cmdlet de Windows si esta disponible.
choice /c SN /n /m "Limpiar caches regenerables? [S/N]: "
if errorlevel 2 goto MAINT_MENU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\MaintenanceV53.ps1" -Mode RegenerableCaches
set "RC=!errorlevel!"
if not "!RC!"=="0" goto MAINT_CACHES_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Add -HistoryFile "%HISTORY%" -Action "Caches" -Detail "Caches regenerables procesadas."
:MAINT_CACHES_RESULT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
pause
goto MAINT_MENU

:MAINT_RECYCLE
choice /c SN /n /m "Vaciar completamente la Papelera? [S/N]: "
if errorlevel 2 goto MAINT_MENU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\MaintenanceV53.ps1" -Mode RecycleBin
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
pause
goto MAINT_MENU

:MAINT_COMPONENTS
echo.
echo Usa DISM /StartComponentCleanup. Puede tardar varios minutos.
echo No usa /ResetBase.
choice /c SN /n /m "Continuar? [S/N]: "
if errorlevel 2 goto MAINT_MENU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\MaintenanceV53.ps1" -Mode ComponentCleanup
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
pause
goto MAINT_MENU

:MAINT_OPTIMIZE
echo.
echo Windows usara defrag /O para elegir la operacion adecuada segun la unidad.
choice /c SN /n /m "Optimizar C:? [S/N]: "
if errorlevel 2 goto MAINT_MENU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\MaintenanceV53.ps1" -Mode OptimizeC
set "RC=!errorlevel!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
pause
goto MAINT_MENU

:MAINT_SHADOW
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\MaintenanceV53.ps1" -Mode ShadowInfo
pause
goto MAINT_MENU

:MAINT_STORAGE_SENSE
start "" ms-settings:storagepolicies
goto MAINT_MENU

:TOOLS_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo HERRAMIENTAS
echo.
echo [1] RED                    Ping, jitter, Speedtest, DNS y adaptadores
echo [2] DRIVERS                Analisis, Windows Update, backup y soporte oficial
echo [3] WINDOWS Y REPARACION   DISM, SFC, CHKDSK y diagnostico
echo [4] RENDIMIENTO            Segundo plano, linea base e historial
echo [5] SOFTWARE               Actualizaciones con WinGet
echo [6] HERRAMIENTAS AVANZADAS WinUtil
echo [7] HERRAMIENTAS WINDOWS   Accesos del sistema
echo [8] COMPONENTES            Dependencias opcionales
echo [9] Volver
choice /c 123456789 /n /m "Elegir: "
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
echo RED
echo.
echo [1] Diagnostico rapido
echo [2] Ping / perdida / jitter
echo [3] Speedtest Ookla
echo [4] DNS: comparar / cambiar / restaurar
echo [5] Traceroute a 1.1.1.1
echo [6] Informacion del adaptador
echo [7] Volver a Herramientas
choice /c 1234567 /n /m "Elegir: "
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
pause
goto NETWORK_MENU
:NET_ADAPTER
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\NetAdapterInfo.ps1"
pause
goto NETWORK_MENU
:NET_TRACE
tracert -d 1.1.1.1
pause
goto NETWORK_MENU
:PINGTEST
for /f %%I in ('powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%I"
set "OUT=%REPORTS%\Ping_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PingTest.ps1" -OutFile "!OUT!"
set "RC=!errorlevel!"
if exist "!OUT!" type "!OUT!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
pause
goto NETWORK_MENU
:SPEEDTEST
for /f %%I in ('powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%I"
set "OUT=%REPORTS%\Speedtest_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\SpeedTestManager.ps1" -OutFile "!OUT!"
set "RC=!errorlevel!"
if exist "!OUT!" type "!OUT!"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Result -Code !RC!
pause
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
echo [6] Restaurar backup
echo [7] Volver a Red
choice /c 1234567 /n /m "Elegir: "
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
pause
goto DNS_MENU
:DNS_CLOUDFLARE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DnsManager.ps1" -Mode Cloudflare -BackupFile "%BACKUPS%\DNS.json"
pause
goto DNS_MENU
:DNS_GOOGLE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DnsManager.ps1" -Mode Google -BackupFile "%BACKUPS%\DNS.json"
pause
goto DNS_MENU
:DNS_QUAD9
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DnsManager.ps1" -Mode Quad9 -BackupFile "%BACKUPS%\DNS.json"
pause
goto DNS_MENU
:DNS_AUTO
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DnsManager.ps1" -Mode Automatic -BackupFile "%BACKUPS%\DNS.json"
pause
goto DNS_MENU
:DNS_RESTORE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DnsManager.ps1" -Mode Restore -BackupFile "%BACKUPS%\DNS.json"
pause
goto DNS_MENU

:DRIVER_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo DRIVERS
echo.
echo [1] Analizar hardware y drivers
echo [2] Buscar drivers con Windows Update
echo [3] Backup de drivers instalados
echo [4] Abrir soporte oficial detectado
echo [5] BIOS / placa madre - solo informacion
echo [6] Volver
choice /c 123456 /n /m "Elegir: "
if errorlevel 6 goto TOOLS_MENU
if errorlevel 5 goto DRIVER_BIOS
if errorlevel 4 goto DRIVER_OFFICIAL
if errorlevel 3 goto DRIVER_BACKUP
if errorlevel 2 goto DRIVER_WU
if errorlevel 1 goto DRIVER_SCAN
goto DRIVER_MENU
:DRIVER_SCAN
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DriverManagerV5.ps1" -Mode Scan -BackupDir "%BACKUPS%"
pause
goto DRIVER_MENU
:DRIVER_WU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DriverManagerV5.ps1" -Mode WindowsUpdate -BackupDir "%BACKUPS%"
pause
goto DRIVER_MENU
:DRIVER_BACKUP
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DriverManagerV5.ps1" -Mode Backup -BackupDir "%BACKUPS%"
pause
goto DRIVER_MENU
:DRIVER_OFFICIAL
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DriverManagerV5.ps1" -Mode Official -BackupDir "%BACKUPS%"
pause
goto DRIVER_MENU
:DRIVER_BIOS
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DriverManagerV5.ps1" -Mode BIOS -BackupDir "%BACKUPS%"
pause
goto DRIVER_MENU

:REPAIR_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo WINDOWS Y REPARACION
echo.
echo [1] Diagnostico de reparacion
echo [2] DISM RestoreHealth
echo [3] SFC /scannow
echo [4] CHKDSK /scan C:
echo [5] Reparacion de red basica
echo [6] Diagnosticar WinGet
echo [7] Volver
choice /c 1234567 /n /m "Elegir: "
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
pause
goto REPAIR_MENU
:REPAIR_DISM
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\RepairCenter.ps1" -Mode DISM
pause
goto REPAIR_MENU
:REPAIR_SFC
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\RepairCenter.ps1" -Mode SFC
pause
goto REPAIR_MENU
:REPAIR_NETWORK
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\RepairCenter.ps1" -Mode Network
pause
goto REPAIR_MENU
:REPAIR_WINGET
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\RepairCenter.ps1" -Mode WinGet
pause
goto REPAIR_MENU
:RUN_CHKDSK
chkdsk C: /scan
pause
goto REPAIR_MENU

:PERF_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo RENDIMIENTO
echo.
echo [1] Que esta ralentizando mi PC?
echo [2] Analizar carga de segundo plano - 30 s
echo [3] Medir ANTES / DESPUES
echo [4] Crear linea base
echo [5] Comparar linea base
echo [6] Ver reinicio pendiente
echo [7] Historial de cambios WinTool
echo [8] Volver
choice /c 12345678 /n /m "Elegir: "
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
echo MEDIR ANTES / DESPUES
echo.
echo Sirve para comprobar cambios reales sin prometer FPS.
echo Haz ambas mediciones con programas y condiciones parecidas.
echo.
echo [1] Guardar medicion ANTES
echo [2] Guardar medicion DESPUES y comparar
echo [3] Mostrar ultima comparacion
echo [4] Volver
choice /c 1234 /n /m "Elegir: "
if errorlevel 4 goto PERF_MENU
if errorlevel 3 goto BEFORE_AFTER_SHOW
if errorlevel 2 goto BEFORE_AFTER_AFTER
if errorlevel 1 goto BEFORE_AFTER_BEFORE
goto BEFORE_AFTER_MENU

:BEFORE_AFTER_BEFORE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\BeforeAfterV54.ps1" -Mode Before -DataFile "%BACKUPS%\AntesDespuesV54.json"
pause
goto BEFORE_AFTER_MENU

:BEFORE_AFTER_AFTER
for /f %%I in ('powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%I"
set "OUT=%REPORTS%\Antes_Despues_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\BeforeAfterV54.ps1" -Mode After -DataFile "%BACKUPS%\AntesDespuesV54.json" -OutFile "!OUT!"
pause
goto BEFORE_AFTER_MENU

:BEFORE_AFTER_SHOW
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\BeforeAfterV54.ps1" -Mode Show -DataFile "%BACKUPS%\AntesDespuesV54.json"
pause
goto BEFORE_AFTER_MENU

:SHOW_HISTORY
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\ChangeHistory.ps1" -Mode Show -HistoryFile "%HISTORY%"
pause
goto PERF_MENU
:BGSCAN
for /f %%I in ('powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%I"
set "OUT=%REPORTS%\Segundo_Plano_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\BackgroundAnalyzer.ps1" -OutFile "!OUT!" -Seconds 30
if exist "!OUT!" type "!OUT!"
pause
goto PERF_MENU
:PERF_REBOOT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PendingReboot.ps1"
pause
goto PERF_MENU
:BASELINE_CREATE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\BaselineV5.ps1" -Mode Create -DataFile "%BACKUPS%\BaselineV5.json" -ReportsDir "%REPORTS%"
pause
goto PERF_MENU
:BASELINE_COMPARE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\BaselineV5.ps1" -Mode Compare -DataFile "%BACKUPS%\BaselineV5.json" -ReportsDir "%REPORTS%"
pause
goto PERF_MENU

:SOFTWARE_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo SOFTWARE / WINGET
echo.
echo [1] Buscar actualizaciones
echo [2] Actualizar todos los paquetes aplicables
echo [3] Abrir Aplicaciones instaladas
echo [4] Volver
choice /c 1234 /n /m "Elegir: "
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
pause
goto SOFTWARE_MENU
:SOFTWARE_UPGRADE
echo Esta opcion puede actualizar varias aplicaciones.
choice /c SN /n /m "Continuar con winget upgrade --all? [S/N]: "
if errorlevel 2 goto SOFTWARE_MENU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\SoftwareCenter.ps1" -Mode UpgradeAll
pause
goto SOFTWARE_MENU

:ADVANCED_TOOLS
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo HERRAMIENTAS AVANZADAS
echo.
echo [1] WinUtil - Chris Titus Tech
echo [2] Volver
choice /c 12 /n /m "Elegir: "
if errorlevel 2 goto TOOLS_MENU
if errorlevel 1 goto OPEN_WINUTIL
goto ADVANCED_TOOLS
:OPEN_WINUTIL
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\WinUtilLauncher.ps1"
pause
goto ADVANCED_TOOLS

:WINDOWS_TOOLS
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo HERRAMIENTAS DE WINDOWS
echo.
echo [1] Administrador de tareas
echo [2] Monitor de recursos
echo [3] Visor de eventos
echo [4] Administrador de dispositivos
echo [5] Administracion de discos
echo [6] Programador de tareas
echo [7] Monitor de rendimiento
echo [8] Informacion del sistema
echo [9] Volver
choice /c 123456789 /n /m "Elegir: "
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
echo [1] Instalar Ookla Speedtest CLI con WinGet
echo [2] Abrir Microsoft Store - App Installer / WinGet
echo [3] Volver
choice /c 123 /n /m "Elegir: "
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
echo [ERROR] WinGet no esta disponible.
pause
goto COMPONENTS_MENU
:INSTALL_SPEEDTEST_OK
choice /c SN /n /m "Instalar Speedtest CLI oficial mediante WinGet? [S/N]: "
if errorlevel 2 goto COMPONENTS_MENU
winget install --id Ookla.Speedtest.CLI -e --accept-source-agreements --accept-package-agreements
pause
goto COMPONENTS_MENU

:ANALYZE_GENERAL
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
for /f %%I in ('powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%I"
set "OUT=%REPORTS%\Analisis_General_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\AnalyzeGeneral.ps1" -OutFile "!OUT!"
if exist "!OUT!" type "!OUT!"
pause
goto DASHBOARD

:ANALYZE_ADV
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo ANALISIS AVANZADO
echo Incluye DISM ScanHealth, SFC verifyonly, CHKDSK /scan C: y eventos recientes.
echo Puede tardar varios minutos. No usa CHKDSK /R.
choice /c SN /n /m "Comenzar? [S/N]: "
if errorlevel 2 goto DASHBOARD
for /f %%I in ('powershell.exe -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "NOW=%%I"
set "OUT=%REPORTS%\Analisis_Avanzado_!NOW!.txt"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\AnalyzeAdvanced.ps1" -OutFile "!OUT!"
echo Reporte: !OUT!
pause
goto DASHBOARD

:CONFIG_MENU
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo CONFIGURACION / RESTAURAR
echo.
echo [1] Historial de cambios WinTool
echo [2] Restaurar Perfil Gaming
echo [3] Restaurar Privacidad
echo [4] Restaurar DNS
echo [5] Restaurar energia
echo [6] Abrir BACKUPS
echo [7] Abrir REPORTES
echo [8] Informacion / seguridad
echo [9] Volver
choice /c 123456789 /n /m "Elegir: "
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
pause
goto CONFIG_MENU

:OPEN_BACKUPS
start "" "%BACKUPS%"
goto CONFIG_MENU

:OPEN_REPORTS
start "" "%REPORTS%"
goto CONFIG_MENU

:RESTORE_GAMING54
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\GamingProfileV54.ps1" -Mode Restore -BackupDir "%BACKUPS%"
pause
goto CONFIG_MENU

:RESTORE_PRIVACY54
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PrivacyV54.ps1" -Mode Restore -BackupDir "%BACKUPS%"
pause
goto CONFIG_MENU

:RESTORE_POWER
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\PowerPlan.ps1" -Mode Restore -BackupFile "%BACKUPS%\PowerPlan.json"
pause
goto CONFIG_MENU

:RESTORE_DNS
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\DnsManager.ps1" -Mode Restore -BackupFile "%BACKUPS%\DNS.json"
pause
goto CONFIG_MENU

:ABOUT
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\UI.ps1" -Mode Header
echo WinTool V!VERSION! reune diagnostico, mantenimiento, optimizacion y herramientas en una interfaz sencilla.
echo.
echo REVISION V!VERSION!:
echo - motor reforzado: rutas, permisos, Windows x64 y componentes verificados;
echo - WinAnalyzer detecta posibles limites de FPS / VSync;
echo - nuevo OPTIMIZAR JUEGO temporal y respetuoso de la configuracion existente;
echo - resultado simple: FPS promedio, 1%% Low, FPS minimo, fluidez, CPU, GPU y RAM;
echo - Datos avanzados separados para no llenar la pantalla principal;
echo - nuevo analisis: QUE ESTA RALENTIZANDO MI JUEGO;
echo - recomendacion y acceso al Perfil Gaming cuando no esta activo;
echo - actividad de disco y carga extra de CPU agregadas al analisis gaming;
echo - compatibilidad con las pruebas guardadas por V5.6.
echo.
echo WinAnalyzer sigue usando PresentMon 2.5.1 integrado para FPS y frametimes.
echo.
echo DATOS DE WINTOOL:
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%\StoragePathsV541.ps1" -Mode Show -BaseDir "%BASE%" -ConfigFile "%BOOTCONFIG%\StorageMode.json"
pause
goto CONFIG_MENU

:STORAGE_FAIL
cls
echo [ERROR] WinTool no pudo preparar sus carpetas de trabajo.
echo.
echo WinTool V!VERSION! usa %%LOCALAPPDATA%%\WinTool para REPORTES, BACKUPS y LOGS.
echo Esto evita conflictos con Escritorio/Documentos protegidos.
echo.
echo No desactives Seguridad de Windows ni agregues cmd.exe como excepcion global.
pause
goto END

:END
endlocal
exit /b
