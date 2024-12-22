@echo off
setlocal EnableDelayedExpansion

echo Checking for Julia installation...

:: Try to run julia --version and capture the output
julia --version > nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Julia is already installed.
    :: Display the version
    julia --version
) else (
    echo Julia is not installed.
    echo Attempting to install Julia using winget...
    
    :: Check if winget is available
    winget --version > nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo Installing Julia from the Microsoft Store...
        winget install julia -s msstore
        
        :: Verify installation was successful
        julia --version > nul 2>&1
        if %ERRORLEVEL% EQU 0 (
            echo Julia installation completed successfully.
            julia --version
        ) else (
            echo Failed to install Julia. Please try installing manually.
        )
        md output
        julia -q --project=. -e "using Pkg; Pkg.instantiate(); using ThermalDiffusivityGUI; ThermalDiffusivityGUI.julia_main()"
    ) else (
        echo Winget is not available on this system.
        echo Please install Julia manually from https://julialang.org/downloads/
    )
)

pause
endlocal
