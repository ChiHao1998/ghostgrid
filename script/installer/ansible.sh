#!/usr/bin/env bash
set -e

source "$(dirname "$0")/logger.sh"

VENV_DIR=".venv"
PYTHON="$VENV_DIR/bin/python"
PIP="$VENV_DIR/bin/pip"

# Function to install Ansible with pip (inside venv)
install_ansible() {
    log INFO "📦 Installing Ansible into virtual environment..."
    if [ ! -d "$VENV_DIR" ]; then
        log INFO "🌱 Creating Python virtual environment at $VENV_DIR..."
        sudo -u "$SUDO_USER" python3 -m venv "$VENV_DIR"
        log SUCCESS "✅ Virtual environment created."
    fi

    # shellcheck disable=SC1091
    source "$VENV_DIR/bin/activate"

    # Upgrade pip + wheel first
    "$PIP" install --upgrade pip wheel >/dev/null 2>&1

    # Install ansible into venv
    "$PIP" install ansible >/dev/null 2>&1
    log SUCCESS "✅ Ansible installed: $($VENV_DIR/bin/ansible --version | head -n 1)"
}
