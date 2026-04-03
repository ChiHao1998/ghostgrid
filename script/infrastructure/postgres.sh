#!/usr/bin/env bash
set -e

SCRIPT_NAME=$(basename "$0")
START_TIME=$(date +%s)

source "./script/logger.sh"

VENV_DIR=".venv"   # adjust if your venv lives elsewhere

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

# Ensure Ansible is installed
if ! command -v ansible >/dev/null 2>&1; then
    log ERROR "❌ Ansible is not installed. Please run ./script/init.sh first."
    exit 1
fi

# --- Ensure community.postgresql Ansible collection is installed ---
if ! ansible-galaxy collection list | grep -q "community.postgresql"; then
    log WARNING "⚠️  Ansible collection community.postgresql not found. Installing..."
    if ansible-galaxy collection install community.postgresql >/dev/null 2>&1; then
        log SUCCESS "✅ community.postgresql collection installed successfully"
    else
        log ERROR "❌ Failed to install community.postgresql collection"
        exit 1
    fi
else
    VERSION=$(ansible-galaxy collection list | awk '/community.postgresql/{print $2}')
    log SUCCESS "✅ community.postgresql collection already installed (version: $VERSION)"
fi

# --- Ensure psycopg2-binary Python package is installed ---
if ! pip show psycopg2-binary >/dev/null 2>&1; then
    log WARNING "⚠️  Python library psycopg2-binary not found. Installing into virtual environment..."
    if pip install psycopg2-binary >/dev/null 2>&1; then
        VERSION=$(pip show psycopg2-binary | awk -F': ' '/^Version/{print $2}')
        log SUCCESS "✅ psycopg2-binary installed successfully (version: $VERSION)"
    else
        log ERROR "❌ Failed to install psycopg2-binary in venv. Try manually: source $VENV_DIR/bin/activate && pip install psycopg2-binary"
        exit 1
    fi
else
    VERSION=$(pip show psycopg2-binary | awk -F': ' '/^Version/{print $2}')
    log SUCCESS "✅ psycopg2-binary Python library is already installed (version: $VERSION)"
fi



cd "./terraform/postgres"

POSTGRES_CONTAINER_NAME="postgres"

# --- Helper: check postgres container state ---
postgres_exists() {
    docker ps -a --format '{{.Names}}' | grep -q "^${POSTGRES_CONTAINER_NAME}$"
}

postgres_running() {
    docker ps --format '{{.Names}}' | grep -q "^${POSTGRES_CONTAINER_NAME}$"
}

# --- Main logic ---
if postgres_exists; then
    if postgres_running; then
        log SUCCESS "ℹ️  PostgreSQL container is already running"
    else
        log WARNING "⚠️  PostgreSQL container exists but is not running. Starting with Terraform..."
        sudo terraform init -input=false -upgrade
        sudo terraform apply -auto-approve
        log SUCCESS "✅ PostgreSQL container started"
        sleep 3
    fi
else
    log INFO "📦 PostgreSQL not found. Provisioning with Terraform..."
    sudo terraform init -input=false -upgrade
    sudo terraform apply -auto-approve
    log SUCCESS "✅ PostgreSQL server installed and running"
    sleep 3
fi