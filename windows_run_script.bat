@echo off
setlocal enabledelayedexpansion

:: Function to log messages with timestamp
call :log "Checking for Julia installation..."

:: Check if Julia is in PATH
where julia >nul 2>&1
if %ERRORLEVEL% equ 0 (
    :: Julia exists in PATH, check version
    for /f "tokens=*" %%i in ('julia --version 2^>^&1') do set "VERSION_OUTPUT=%%i"
    if not !ERRORLEVEL! equ 0 (
        call :log "Julia command exists but version check failed. Installing fresh copy..."
        call :install_julia
    ) else (
        call :log "Julia is already installed: !VERSION_OUTPUT!"
        goto :verification
    )
) else (
    call :log "Julia not found. Proceeding with installation..."
    call :install_julia
)

:verification
:: Verify installation
where julia >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "tokens=*" %%i in ('julia --version 2^>^&1') do set "FINAL_VERSION=%%i"
    call :log "Verification successful: !FINAL_VERSION!"
    exit /b 0
) else (
    call :log "Error: Julia installation verification failed"
    exit /b 1
)

:: Function to install Julia
:install_julia
call :log "Installing Julia..."

:: Create temporary directory for installer
set "TEMP_DIR=%TEMP%\julia_installer"
mkdir "%TEMP_DIR%" 2>nul

:: Download installer using PowerShell
powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://julialang-s3.julialang.org/bin/winnt/x64/1.9/julia-1.9.3-win64.exe' -OutFile '%TEMP_DIR%\julia_installer.exe'}"

if not exist "%TEMP_DIR%\julia_installer.exe" (
    call :log "Error: Failed to download Julia installer"
    exit /b 1
)

:: Run installer
call :log "Running installer..."
start /wait "" "%TEMP_DIR%\julia_installer.exe" /SILENT /NORESTART

:: Clean up
del /q "%TEMP_DIR%\julia_installer.exe"
rmdir "%TEMP_DIR%"

:: Refresh environment variables
call :refresh_env
goto :eof

:: Function to log messages
:log
echo [%date% %time%] %~1
goto :eof

:: Function to refresh environment variables
:refresh_env
call :log "Refreshing environment variables..."
for /f "tokens=2*" %%a in ('reg query HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment /v Path') do set "PATH=%%b"
for /f "tokens=2*" %%a in ('reg query HKEY_CURRENT_USER\Environment /v Path') do set "PATH=!PATH!;%%b"
goto :eof

endlocal
