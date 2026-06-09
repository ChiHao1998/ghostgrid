#!/usr/bin/env bash
set -euo pipefail
: "${GHOSTGRID_ROOT:?must invoke via main.sh}"
source "$GHOSTGRID_ROOT/script/logger.sh"
source "$GHOSTGRID_ROOT/lib/vault.sh"

vault_ensure_ready

ask "new username" "" USERNAME

log INFO "checking user '$USERNAME'..."
if vault_user_exists "$USERNAME"; then
    log INFO "user '$USERNAME' exists — skipping creation"
else
    ask_secret "password for '$USERNAME'" USER_PASSWORD

    vault_ensure_userpass

    log INFO "creating user '$USERNAME'..."
    vault_api POST "auth/userpass/users/$USERNAME" \
        -H "Content-Type: application/json" \
        -d "{\"password\": $(printf '%s' "$USER_PASSWORD" | jq -Rs .)}"
    log SUCCESS "user '$USERNAME' created"
fi

log INFO "updating admin policy for '$USERNAME'..."
vault_policy_upsert_block "admin" "$(printf 'path "auth/userpass/users/%s" {\n  capabilities = ["create", "read", "update", "delete", "list"]\n}' "$USERNAME")"

log SUCCESS "user '$USERNAME' ready"
log INFO "username : $USERNAME"
