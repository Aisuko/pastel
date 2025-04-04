#!/bin/bash
# This script checks the Podman version and installs podman-compose if it is not already installed.

# Author: Bowen
# Date: 2025-04-04

# Check if Podman is installed
if ! command -v podman &>/dev/null; then
    echo "Podman is not installed. Please install Podman first."
    exit 1
fi

# Display Podman version
echo "Podman version:"
podman --version

# Check if podman-compose is already installed
if command -v podman-compose &>/dev/null; then
    echo "podman-compose is already installed."
else
    echo "podman-compose is not installed. Attempting installation..."

    # First try to install using dnf
    if sudo dnf install -y podman-compose; then
        echo "podman-compose installed successfully using dnf."
    else
        echo "dnf installation failed, trying pip3..."
        # Attempt installation using pip3
        if pip3 install podman-compose; then
            echo "podman-compose installed successfully using pip3."
        else
            echo "Failed to install podman-compose. Please install it manually."
            exit 1
        fi
    fi
fi

