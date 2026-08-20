@echo off
title USB SysAdmin Universal Toolbox
chcp 65001 >nul
cd /d "%~dp0"

:: 1. Проверка прав Администратора и автоматический перезапуск
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -Verb RunAs -FilePath '%~f0'" 2>nul
    exit /b
)

:: 2. Проверка наличия PowerShell
where powershell >nul 2>&1
if %errorLevel% neq 0 (
    goto :CMD_FALLBACK
)

:: 3. Запуск чистого PowerShell модуля
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Toolbox.ps1"
if %errorLevel% neq 0 (
    echo.
    echo [-] Ошибка выполнения PowerShell скрипта.
    pause
)
exit /b

:CMD_FALLBACK
cls
color 1F
echo ============================================================
echo      РЕЖИМ СОВМЕСТИМОСТИ (LEGACY CMD MENU)
echo ============================================================
echo [1] Открыть папку с диагностикой (AIDA64 / Victoria / CPU-Z)
echo [2] Запуск проверки диска (CHKDSK C: /F)
echo [3] Проверка целостности (SFC /SCANNOW)
echo [4] Сброс сети (Netsh Winsock Reset)
echo [0] Выход
echo ============================================================
set /p choice="Выберите действие (0-4): "
if "%choice%"=="1" start "" "%~dp0Programs\Diagnostic" & goto :CMD_FALLBACK
if "%choice%"=="2" chkdsk C: /f & pause & goto :CMD_FALLBACK
if "%choice%"=="3" sfc /scannow & pause & goto :CMD_FALLBACK
if "%choice%"=="4" netsh winsock reset & echo Перезагрузите ПК & pause & goto :CMD_FALLBACK
if "%choice%"=="0" exit /b
goto :CMD_FALLBACK
