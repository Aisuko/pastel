#!/bin/bash

# author: Bowen
# Date: 2025-04-04

set -e

USERNAME="ec2-user"

# Check if running as root. If so, perform system-level tasks and then re-exec as the non-root user.
if [ "$EUID" -eq 0 ]; then
  echo "Running as root: installing prerequisites and configuring $USERNAME..."
  apt-get update
  apt-get install -y uidmap dbus-user-session

  # Configure subordinate UID/GID ranges if not already set.
  if ! grep -q "^$USERNAME:" /etc/subuid; then
    usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$USERNAME"
  fi

  # Enable linger so that user systemd services can run without an active login session.
  loginctl enable-linger "$USERNAME"

  echo "System prerequisites complete. Re-executing the script as $USERNAME..."
  # Re-run this script as the unprivileged user.
  exec sudo -u "$USERNAME" env "HOME=/home/$USERNAME" bash "$0" nonroot
fi

# When we reach here, we're running as the unprivileged user (ec2-user).
echo "Running as $(whoami). Proceeding with Docker rootless installation..."

# Ensure the PATH includes $HOME/bin (where Docker binaries will be installed).
export PATH="$HOME/bin:$PATH"

# Set XDG_RUNTIME_DIR if not already set.
if [ -z "$XDG_RUNTIME_DIR" ] || [ ! -d "$XDG_RUNTIME_DIR" ]; then
  if [ -d "/run/user/$(id -u)" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
  else
    export XDG_RUNTIME_DIR="$HOME/.docker/run"
    mkdir -p "$XDG_RUNTIME_DIR"
  fi
fi

export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"

# Remove any existing Docker binary to force a clean installation.
if [ -x "$HOME/bin/dockerd" ]; then
  echo "Removing existing Docker binary at $HOME/bin/dockerd"
  rm -f "$HOME/bin/dockerd"
fi

# Force the Docker rootless installation.
echo "Installing Docker rootless mode..."
FORCE_ROOTLESS_INSTALL=1 curl -fsSL https://get.docker.com/rootless | sh

# Attempt to reload user systemd daemon and start Docker.
if systemctl --user daemon-reload >/dev/null 2>&1; then
    systemctl --user start docker || echo "Warning: Failed to start Docker via systemctl --user."
    systemctl --user enable docker || echo "Warning: Failed to enable Docker via systemctl --user."
else
    echo "User systemd not available. Please start Docker manually using 'dockerd-rootless.sh'."
fi

echo "Docker rootless installation is complete."
echo "For future sessions, add the following lines to your ~/.bashrc or ~/.profile:"
echo 'export PATH="$HOME/bin:$PATH"'
echo 'export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"'

