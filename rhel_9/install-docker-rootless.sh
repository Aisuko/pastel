#!/bin/bash
# install-docker-rootless.sh - Automates installation of Docker in rootless mode on RHEL9
#
# Author: Bowen
# Date: 2025-04-04
# 
# Usage (as root):
#   sudo ./install-docker-rootless.sh [--user-name <username>]
#
# The script does:
# 1. Root-level tasks:
#    - Update system & install prerequisites.
#    - Add Docker repository.
#    - Install Docker Engine packages (including rootless extras).
#    - Set up /etc/subuid and /etc/subgid for the specified user.
#    - Enable linger for the user.
#
# 2. Non-root tasks:
#    - Re-executes itself as the non-root user to run dockerd-rootless-setuptool.sh.
#    - Sets environment variables (XDG_RUNTIME_DIR, DOCKER_HOST).
#    - Reloads and starts the Docker systemd user service.
#
# Adjust variables as needed.
#
# Requirements:
# - RHEL9 with a valid subscription.
# - The non-root user (default: ec2-user) must log in via SSH (or similar) so that systemd user services work properly.

set -euo pipefail

# Default values
DEFAULT_USER="ec2-user"
DOCKER_VERSION="28.0.1-1.el9"
NONROOT_FLAG=false
USERNAME="$DEFAULT_USER"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --user-name)
            USERNAME="$2"
            shift 2
            ;;
        --nonroot)
            NONROOT_FLAG=true
            shift
            ;;
        --help)
            echo "Usage: $0 [--user-name <username>] [--nonroot]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# If running as root and not in non-root mode, perform system-level tasks
if [[ "$EUID" -eq 0 && "$NONROOT_FLAG" = false ]]; then
    echo "Running as root. Setting up prerequisites for Docker rootless installation on RHEL9 for user $USERNAME..."
    
    # Update system and install prerequisites
    dnf update -y
    # dnf install -y dnf-plugins-core uidmap dbus-user-session iptables fuse-overlayfs
    dnf install -y dnf-plugins-core iptables fuse-overlayfs
    
    # Load the ip_tables module if not already loaded
    if ! lsmod | grep -q ip_tables; then
        echo "Loading ip_tables module..."
        modprobe ip_tables
    fi

    # Add Docker CE repository
    dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
    
    # Install Docker Engine packages including rootless extras
    dnf install -y "docker-ce-3:${DOCKER_VERSION}" "docker-ce-cli-1:${DOCKER_VERSION}" containerd.io "docker-ce-rootless-extras-${DOCKER_VERSION}"
    
    # Configure subordinate UID/GID for the non-root user if not already set
    if ! grep -q "^${USERNAME}:" /etc/subuid; then
      echo "${USERNAME}:100000:65536" >> /etc/subuid
    fi
    if ! grep -q "^${USERNAME}:" /etc/subgid; then
      echo "${USERNAME}:100000:65536" >> /etc/subgid
    fi

    # Enable linger for the user so that systemd user services continue running after logout
    loginctl enable-linger "$USERNAME"

    echo "Root-level installation complete."
    echo "Switching to non-root setup for user $USERNAME..."
    
    # Re-run the script as the specified non-root user
    sudo -u "$USERNAME" bash -c "export XDG_RUNTIME_DIR=/run/user/\$(id -u); $(realpath "$0") --nonroot --user-name $USERNAME"
    exit 0
fi

# Non-root part: This block runs when --nonroot flag is set
if [[ "$NONROOT_FLAG" = true ]]; then
    echo "Running non-root setup as user $(id -un)"
    
    # Ensure XDG_RUNTIME_DIR is set properly; systemd normally sets it upon login
    if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
      export XDG_RUNTIME_DIR=/run/user/$(id -u)
    fi
    
    # Set DOCKER_HOST to point to the Docker socket in the systemd user runtime directory
    export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/docker.sock"
    # Ensure PATH includes /usr/bin (adjust if needed)
    export PATH="/usr/bin:$PATH"
    
    # Run the Docker rootless setup tool (it should be installed with docker-ce-rootless-extras)
    if command -v dockerd-rootless-setuptool.sh >/dev/null 2>&1; then
       dockerd-rootless-setuptool.sh install
    else
       echo "Error: dockerd-rootless-setuptool.sh not found in PATH."
       exit 1
    fi
    
    # Reload the user systemd daemon, start and enable the Docker service
    systemctl --user daemon-reload
    systemctl --user start docker
    systemctl --user enable docker

    echo "Docker rootless installation complete for user $(id -un)."
    echo "Please add the following lines to your ~/.bashrc (or equivalent) so they persist across sessions:"
    echo "  export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}"
    echo "  export DOCKER_HOST=unix://${XDG_RUNTIME_DIR}/docker.sock"
    echo "  export PATH=/usr/bin:\$PATH"
    echo "You can now use Docker commands (e.g., 'docker ps', 'docker run hello-world')."
fi

