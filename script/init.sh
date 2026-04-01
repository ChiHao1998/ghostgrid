#!/usr/bin/env bash
set -e

source ./script/installer/terraform.sh
source ./script/installer/ansible.sh
source ./script/installer/python.sh
source "$(dirname "$0")/logger.sh"

log INFO "🔍 Checking prerequisites for Infrastructure as Code (IaC) repo..."

# Function to check if a command exists
check_command() {
    local cmd=$1
    if ! command -v "$cmd" &> /dev/null; then
        if [ "$cmd" = "terraform" ]; then
            log WARNING "❌ Terraform is not installed."
            install_terraform
        elif [ "$cmd" = "ansible" ]; then
            log WARNING "❌ Ansible is not installed."
            install_ansible
        elif [ "$cmd" = "docker" ]; then
            log ERROR "❌ Docker CLI not found. Please install Docker Engine or start Docker Desktop (Windows/Mac) or run 'systemctl start docker' (Linux).."
            exit 1
        elif [ "$cmd" = "python3" ]; then
            log ERROR "❌ Python3 is not installed."
            install_python
            exit 1
        fi   # ← this was missing
    else
        log SUCCESS "✅ $cmd is installed: $($cmd --version | head -n 1)"
    fi
}

# Check Docker CLI
check_command docker

# Check Docker daemon
if ! docker info >/dev/null 2>&1; then
    log ERROR "🐳 Docker CLI is installed but the Docker daemon is not running."
    exit 1
else
    log SUCCESS "🐳 Docker daemon is running."
fi

# --- Python and Virtual Environment Setup ---
check_command python3

VENV_DIR=".venv"

if [ ! -d "$VENV_DIR" ]; then
    log INFO "🌱 Creating Python virtual environment at $VENV_DIR..."
    sudo -u "$SUDO_USER" python3 -m venv "$VENV_DIR"
    log SUCCESS "✅ Virtual environment created."
fi

# Activate venv
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
log SUCCESS "🐍 Activated Python virtual environment: $(python --version)"

# Upgrade pip and wheel inside venv
pip install --upgrade pip wheel >/dev/null 2>&1
log SUCCESS "⚙️  pip and wheel upgraded inside venv."

# Check and install Terraform
check_command terraform

# Check and install Ansible
check_command ansible

log SUCCESS "🎉 All prerequisites are installed. You're good to go!"
