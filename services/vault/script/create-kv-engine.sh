#!/usr/bin/env bash
set -euo pipefail
: "${GHOSTGRID_ROOT:?must invoke via main.sh}"
source "$GHOSTGRID_ROOT/script/logger.sh"
source "$GHOSTGRID_ROOT/lib/vault.sh"
KV_PATH="${KV_PATH:-secret}"

vault_ensure_ready

ask "KV engine path" "$KV_PATH" KV_PATH

log INFO "checking mounts..."
if vault_mount_exists "$KV_PATH"; then
    log INFO "KV engine already mounted at '${KV_PATH}/' — nothing to do"
    exit 0
fi

log INFO "enabling KV v2 at '${KV_PATH}/'..."
vault_api POST "sys/mounts/${KV_PATH}" \
    -H "Content-Type: application/json" \
    -d '{"type":"kv","options":{"version":"2"}}'

log SUCCESS "KV v2 enabled at '${KV_PATH}/'"
log INFO "path : ${KV_PATH}/"
log INFO "addr : $VAULT_ADDR/ui/vault/secrets/${KV_PATH}"
