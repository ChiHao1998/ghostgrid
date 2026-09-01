#!/usr/bin/env bash
set -e
: "${GHOSTGRID_ROOT:?must invoke via main.sh}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$GHOSTGRID_ROOT/script/logger.sh"
source "$GHOSTGRID_ROOT/lib/service.sh"

DATA_DIR="$HOME/.vault"
mkdir -p "$DATA_DIR"
smart_install vault docker.io/hashicorp/vault:latest \
    --cap-add IPC_LOCK \
    -p 8200:8200 \
    -v "$SCRIPT_DIR/config:/vault/config" \
    -v "$DATA_DIR:/vault/data" \
    -e VAULT_ADDR=http://127.0.0.1:8200 \
    -e VAULT_API_ADDR=http://127.0.0.1:8200 \
    -- vault server -config=/vault/config/vault-config.json
log INFO "UI http://localhost:8200"
