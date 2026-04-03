#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME=$(basename "$0")
START_TIME=$(date +%s)

if [[ -f "$(dirname "$0")/script/logger.sh" ]]; then
    source "$(dirname "$0")/script/logger.sh"
else
    log() { echo "[$(date +"%Y-%m-%d %H:%M:%S")] [$1] $2"; }
fi

log INFO "🗑 Starting full reset..."

#####################################
# Remove Terraform
#####################################
log INFO "📦 Removing Terraform..."
if command -v terraform >/dev/null 2>&1; then
    sudo apt-get purge --auto-remove terraform -y || true
    sudo rm -f /usr/local/bin/terraform || true
    sudo rm -rf ~/.terraform.d || true
    log SUCCESS "✅ Terraform removed"
else
    log WARNING "⚠️  Terraform not found, skipping..."
fi

#####################################
# Remove Vault data
#####################################
if [[ -d "terraform/vault/data" ]]; then
    log INFO "📂 Removing Vault data directory..."
    sudo rm -rf terraform/vault/data/* || true
    log SUCCESS "✅ Vault data removed"
else
    log WARNING "⚠️  No Vault data found, skipping..."
fi

#####################################
# Remove Python virtual environment
#####################################
if [[ -d ".venv" ]]; then
    log INFO "🐍 Removing Python virtual environment..."
    sudo rm -rf .venv || true
    log SUCCESS "✅ .venv removed"
else
    log WARNING "⚠️  No .venv found, skipping..."
fi

#####################################
# Clean up APT sources
#####################################
log INFO "🧹 Cleaning up APT sources..."
sudo rm -f /etc/apt/sources.list.d/hashicorp.list || true
sudo rm -f /etc/apt/sources.list.d/ansible.list || true
sudo apt-get update -y || true

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

log SUCCESS "🎉 Reset complete!"
