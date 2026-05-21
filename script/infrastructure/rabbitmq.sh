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

# Ensure Terraform is installed
if ! command -v terraform >/dev/null 2>&1; then
    log ERROR "❌ Terraform is not installed. Please run ./script/init.sh first."
    exit 1
fi

# Ensure Docker is installed
if ! command -v docker >/dev/null 2>&1; then
    log ERROR "❌ Docker is not installed. Please run ./script/init.sh first."
    exit 1
fi

cd "./terraform/rabbitmq"

RABBITMQ_CONTAINER_NAME="rabbitmq"

# --- Helper: check rabbitmq container state ---
rabbitmq_exists() {
    docker ps -a --format '{{.Names}}' | grep -q "^${RABBITMQ_CONTAINER_NAME}$"
}

rabbitmq_running() {
    docker ps --format '{{.Names}}' | grep -q "^${RABBITMQ_CONTAINER_NAME}$"
}

# --- Main logic ---
if rabbitmq_exists; then
    if rabbitmq_running; then
        log SUCCESS "ℹ️  RabbitMQ container is already running"
    else
        log WARNING "⚠️  RabbitMQ container exists but is not running. Starting with Terraform..."
        sudo terraform init -input=false -upgrade
        sudo terraform apply -auto-approve
        log SUCCESS "✅ RabbitMQ container started"
        sleep 3
    fi
else
    log INFO "📦 RabbitMQ not found. Provisioning with Terraform..."
    sudo terraform init -input=false -upgrade
    sudo terraform apply -auto-approve
    log SUCCESS "✅ RabbitMQ server installed and running"
    sleep 3
fi

log INFO "🌐 RabbitMQ Management UI: http://localhost:15672"
log INFO "🔌 RabbitMQ AMQP Port: localhost:5672"