#!/usr/bin/env bash
set -e

source "$(dirname "$0")/logger.sh"

# Function to install Terraform
install_terraform() {
    log INFO "📦 Installing Terraform..."
    sudo apt-get update -y
    sudo apt-get install -y curl gnupg software-properties-common

    curl -fsSL https://apt.releases.hashicorp.com/gpg \
        | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
        | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null

    sudo apt-get update -y
    sudo apt-get install -y terraform
    log SUCCESS "✅ Terraform installed: $(terraform --version | head -n 1)"
}