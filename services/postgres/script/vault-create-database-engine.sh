#!/usr/bin/env bash
set -euo pipefail
: "${GHOSTGRID_ROOT:?must invoke via main.sh}"
source "$GHOSTGRID_ROOT/script/logger.sh"
source "$GHOSTGRID_ROOT/lib/vault.sh"

vault_ensure_ready

ask "postgres host" "127.0.0.1" DB_HOST
ask "postgres port" "5432" DB_PORT
ask "postgres admin username" "postgres" DB_ADMIN_USER
ask_secret "postgres admin password" DB_ADMIN_PASSWORD
ask "database name" "" DB_NAME
ask "vault database engine name" "" ENGINE_NAME

log INFO "checking mounts..."
if vault_mount_exists "$ENGINE_NAME"; then
    log INFO "engine '${ENGINE_NAME}' already mounted — skipping enable"
else
    log INFO "enabling database engine at '${ENGINE_NAME}'..."
    vault_api POST "sys/mounts/${ENGINE_NAME}" \
        -H "Content-Type: application/json" \
        -d '{"type":"database"}'
    log SUCCESS "database engine enabled at '${ENGINE_NAME}'"
fi

log INFO "configuring postgres connection '${DB_NAME}' in engine '${ENGINE_NAME}'..."
conn_url="postgresql://${DB_ADMIN_USER}:${DB_ADMIN_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable"
vault_api POST "${ENGINE_NAME}/config/${DB_NAME}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
        --arg plugin  "postgresql-database-plugin" \
        --arg roles   "*" \
        --arg connurl "$conn_url" \
        '{plugin_name: $plugin, allowed_roles: $roles, connection_url: $connurl}')"

log SUCCESS "vault postgresql engine '${ENGINE_NAME}' configured for database '${DB_NAME}'"
log INFO "engine : ${ENGINE_NAME}/config/${DB_NAME}"
log INFO "addr   : $VAULT_ADDR/ui/vault/secrets/${ENGINE_NAME}"
