#!/usr/bin/env bash
set -euo pipefail

: "${GHOSTGRID_ROOT:?must invoke via main.sh}"
source "$GHOSTGRID_ROOT/script/logger.sh"
source "$GHOSTGRID_ROOT/lib/vault.sh"

POLICY_BLOCKS=(
'path "sys/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}'
'path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}'
'path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}'
'path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}'
'path "auth/token/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}'
)

# ---------- 1. bootstrap auth (status check + root token) ----------
vault_init_bootstrap

# ---------- 2. check admin user ----------
log INFO "checking admin user..."
if vault_user_exists "admin"; then
    log INFO "admin user exists — nothing to do"
    exit 0
fi
log INFO "user 'admin' not found — proceeding"

# ---------- 4. prompt password ----------
ask_secret "admin password" ADMIN_PASSWORD

# ---------- 5. enable userpass auth ----------
vault_ensure_userpass

# ---------- 6. create admin user ----------
log INFO "creating admin user..."
vault_api POST auth/userpass/users/admin \
    -H "Content-Type: application/json" \
    -d "{\"password\": $(printf '%s' "$ADMIN_PASSWORD" | jq -Rs .), \"policies\": \"admin\"}"
log SUCCESS "user 'admin' created"

# ---------- 7. upsert policy paths ----------
log INFO "updating admin policy..."
for block in "${POLICY_BLOCKS[@]}"; do
    vault_policy_upsert_block "admin" "$block"
done
log SUCCESS "admin policy up to date"

log SUCCESS "admin setup complete"
log INFO "username : admin"
log INFO "password : $ADMIN_PASSWORD"
