#!/bin/bash

# Set error handling
set -e

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Julia
install_julia() {
    log_message "Installing Julia..."
    if ! curl -fsSL https://install.julialang.org | sh; then
        log_message "Error: Failed to install Julia"
        exit 1
    fi
    log_message "Julia installation completed"
}

# Main script
log_message "Checking for Julia installation..."

if command_exists julia; then
    VERSION_OUTPUT=$(julia --version 2>&1)
    if [ $? -eq 0 ]; then
        log_message "Julia is already installed: $VERSION_OUTPUT"
    else
        log_message "Julia command exists but version check failed. Installing fresh copy..."
        install_julia
    fi
else
    log_message "Julia not found. Proceeding with installation..."
    install_julia
fi

# Verify installation
if command_exists julia; then
    FINAL_VERSION=$(julia --version)
    log_message "Verification successful: $FINAL_VERSION"
    if ! [ -d ./output/ ]; then
    	mkdir output

    fi
    julia -q --project=. -e "using Pkg; Pkg.instantiate(); using ThermalDiffusivityGUI; ThermalDiffusivityGUI.julia_main()"
else
    log_message "Error: Julia installation verification failed"
    exit 1
fi
Ben
