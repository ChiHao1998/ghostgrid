#!/usr/bin/env bash
set -e

SCRIPT_NAME=$(basename "$0")
START_TIME=$(date +%s)

source "./script/logger.sh"

VENV_DIR=".venv"

# --- Activate Python venv if available ---
if [ -d "$VENV_DIR" ]; then
    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate"
    log INFO "🌱 Virtual environment activated ($VENV_DIR)"
else
    log ERROR "❌ Virtual environment not found at $VENV_DIR. Please run ./script/init.sh first."
    exit 1
fi

# --- Ensure Terraform is installed ---
if ! command -v terraform >/dev/null 2>&1; then
    log ERROR "❌ Terraform is not installed. Please run ./script/init.sh first."
    exit 1
fi

cd "./terraform/mailpit"

MAILPIT_CONTAINER_NAME="mailpit"

# --- Helper: check container state ---
mailpit_exists() {
    docker ps -a --format '{{.Names}}' | grep -q "^${MAILPIT_CONTAINER_NAME}$"
}

mailpit_running() {
    docker ps --format '{{.Names}}' | grep -q "^${MAILPIT_CONTAINER_NAME}$"
}

# --- Main logic ---
if mailpit_exists; then
    if mailpit_running; then
        log SUCCESS "ℹ️  Mailpit container is already running"
    else
        log WARNING "⚠️  Mailpit container exists but is not running. Starting with Terraform..."
        terraform init -input=false -upgrade
        terraform apply -auto-approve
        log SUCCESS "✅ Mailpit container started"
    fi
else
    log INFO "📦 Mailpit not found. Provisioning with Terraform..."
    terraform init -input=false -upgrade
    terraform apply -auto-approve
    log SUCCESS "✅ Mailpit installed and running"
fi

# --- Output info ---
log INFO "📬 Mailpit SMTP: localhost:1025"
log INFO "🌐 Mailpit UI: http://localhost:8025"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

log INFO "⏱️ Completed in ${DURATION}s"