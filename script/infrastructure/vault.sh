#!/usr/bin/env bash
set -e

SCRIPT_NAME=$(basename "$0")
START_TIME=$(date +%s)

source "./script/logger.sh"

VAULT_KEYS_FILE="./data/vault-keys.json"
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

# Ensure Ansible collection community.hashi_vault is installed
if ! ansible-galaxy collection list | grep -q "community.hashi_vault"; then
    log WARNING "⚠️ Ansible galaxy collection community.hashi_vault collection not found. Installing..."
    ansible-galaxy collection install community.hashi_vault
    log SUCCESS "✅ Ansible galaxy collection community.hashi_vault installed"
else
    log SUCCESS "✅ Ansible galaxy collection community.hashi_vault has already installed"
fi

# Ensure hvac Python package is installed (inside venv)
if ! pip show hvac >/dev/null 2>&1; then
    log WARNING "⚠️  Python library hvac not found. Installing into virtual environment..."
    if pip install hvac >/dev/null 2>&1; then
        VERSION=$(pip show hvac | awk -F': ' '/^Version/{print $2}')
        log SUCCESS "✅ hvac installed successfully (version: $VERSION)"
    else
        log ERROR "❌ Failed to install hvac in venv. Try manually: source $VENV_DIR/bin/activate && pip install hvac"
        exit 1
    fi
else
    VERSION=$(pip show hvac | awk -F': ' '/^Version/{print $2}')
    log SUCCESS "✅ hvac Python library is already installed (version: $VERSION)"
fi

cd "./terraform/vault"

# Get Vault URL
get_vault_url() {
    if docker ps -a --format '{{.Names}}' | grep -q "^vault$"; then
        VAULT_PORT=$(docker inspect -f '{{range $p, $conf := .NetworkSettings.Ports}}{{if eq $p "8200/tcp"}}{{(index $conf 0).HostPort}}{{end}}{{end}}' vault)
        if [ -n "$VAULT_PORT" ]; then
            echo "http://127.0.0.1:${VAULT_PORT}"
        else
            INTERNAL_PORT=$(docker inspect -f '{{range $p, $_ := .NetworkSettings.Ports}}{{if (index . 0)}}{{$p}}{{end}}{{end}}' vault | cut -d'/' -f1 | head -n1)
            [ -z "$INTERNAL_PORT" ] && INTERNAL_PORT=8200
            VAULT_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' vault)
            echo "http://${VAULT_IP}:${INTERNAL_PORT}"
        fi
    fi
}

# Start Vault container if needed
if docker ps -a --format '{{.Names}}' | grep -q "^vault$"; then
    VAULT_URL=$(get_vault_url)
    if docker ps --format '{{.Names}}' | grep -q "^vault$"; then
        log SUCCESS "✅ Vault is already installed and running (at $VAULT_URL)"
    else
        log WARNING "⚠️  Vault container exists but is not running. Starting with Terraform..."
        sudo terraform init -input=false -upgrade
        sudo terraform apply -auto-approve
        VAULT_URL=$(terraform output -raw vault_ui_url)
        log SUCCESS "✅ Vault container restarted (running at $VAULT_URL)"
        sleep 5
    fi
else
    log INFO "📦 Starting Vault installation with Terraform (Docker)..."
    sudo terraform init -input=false -upgrade
    sudo terraform apply -auto-approve
    VAULT_URL=$(terraform output -raw vault_ui_url)
    log SUCCESS "✅ Vault installed successfully (running at $VAULT_URL)"
    log INFO "⏳ Waiting for Vault Server to start..."
    sleep 5
fi

VAULT_CLI="docker exec -i vault vault"

STATUS=$(sudo $VAULT_CLI status -format=json || true)
INITIALIZED=$(echo "$STATUS" | grep -o '"initialized":[^,]*' | cut -d: -f2 | tr -d ' ')
SEALED=$(echo "$STATUS" | grep -o '"sealed":[^,]*' | cut -d: -f2 | tr -d ' ')

if [ "$INITIALIZED" = "true" ]; then
    if [ "$SEALED" = "true" ]; then
        log WARNING "🔒 Vault is initialized but sealed."
        echo "Please enter unseal keys one by one (press Enter after each). Leave empty to stop:"
        while true; do
            read -s -p "Unseal Key: " KEY
            echo
            [ -z "$KEY" ] && break

            if ! $VAULT_CLI operator unseal "$KEY" >/dev/null 2>&1; then
                log ERROR "❌ Failed with provided key"
                continue
            fi

            STATUS=$($VAULT_CLI status -format=json || true)
            SEALED=$(echo "$STATUS" | grep -o '"sealed":[^,]*' | cut -d: -f2 | tr -d ' ')
            PROGRESS=$(echo "$STATUS" | grep -o '"progress":[^,]*' | cut -d: -f2 | tr -d ' ')
            THRESHOLD=$(echo "$STATUS" | grep -o '"t":[^,]*' | cut -d: -f2 | tr -d ' ')

            if [ "$SEALED" = "false" ]; then
                log SUCCESS "🔓 Vault unsealed successfully (progress $THRESHOLD/$THRESHOLD)"
                break
            else
                log INFO "🗝️  Unseal progress: $PROGRESS/$THRESHOLD"
            fi
        done
    else
        log SUCCESS "✅ Vault is already initialized and unsealed"
    fi
else
    if [ ! -s "$VAULT_KEYS_FILE" ]; then
        log INFO "🚀 Vault not initialized. Initializing now..."
        sudo $VAULT_CLI operator init -format=json | sudo tee "$VAULT_KEYS_FILE" > /dev/null
        log SUCCESS "🔑 Vault initialized. Keys written to: $VAULT_KEYS_FILE"
        log INFO "ℹ️  Unseal keys and root token are sensitive!"
        log INFO "🚛 Move $VAULT_KEYS_FILE to a secure location immediately."
        log INFO "⚠️  Do NOT commit this file to git or share it."
    else
        log ERROR "❌ Vault already initialized, and key file exists at $VAULT_KEYS_FILE"
        log INFO  "ℹ️  Delete the file manually if you *really* want to re-init Vault"
    fi
fi
