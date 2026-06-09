#!/usr/bin/env bash
set -euo pipefail
: "${GHOSTGRID_ROOT:?must invoke via main.sh}"
source "$GHOSTGRID_ROOT/script/logger.sh"
source "$GHOSTGRID_ROOT/lib/vault.sh"

vault_ensure_ready

ask "KV engine path" "secret" KV_PATH

log INFO "verifying KV engine at '${KV_PATH}/'..."
if ! vault_mount_exists "$KV_PATH"; then
    log ERROR "KV engine '${KV_PATH}/' not mounted — run create-kv-engine first"
    exit 1
fi
log INFO "KV engine '${KV_PATH}/' found"

ask "username" "" USERNAME

log INFO "verifying user '$USERNAME'..."
if ! vault_user_exists "$USERNAME"; then
    log ERROR "user '$USERNAME' not found — run create-user first"
    exit 1
fi
log INFO "user '$USERNAME' exists"

POLICY_NAME="kv-${KV_PATH//\//-}-read"

log INFO "checking policies for '$USERNAME'..."
user_data=$(vault_api GET "auth/userpass/users/$USERNAME")
current_policies=$(printf '%s' "$user_data" | jq -r '.data.policies // [] | join(",")')

if printf '%s' "$current_policies" | grep -qF "$POLICY_NAME"; then
    log INFO "policy '$POLICY_NAME' already attached to '$USERNAME' — nothing to do"
    exit 0
fi

log INFO "writing policy '$POLICY_NAME'..."
POLICY_HCL="path \"${KV_PATH}/data/*\" {
  capabilities = [\"read\", \"list\"]
}
path \"${KV_PATH}/metadata/*\" {
  capabilities = [\"list\"]
}"
vault_api PUT "sys/policies/acl/$POLICY_NAME" \
    -H "Content-Type: application/json" \
    -d "{\"policy\": $(printf '%s' "$POLICY_HCL" | jq -Rs .)}"
log SUCCESS "policy '$POLICY_NAME' written"

log INFO "attaching '$POLICY_NAME' to '$USERNAME'..."
if [[ -n "$current_policies" ]]; then
    new_policies="${current_policies},${POLICY_NAME}"
else
    new_policies="$POLICY_NAME"
fi
vault_api POST "auth/userpass/users/$USERNAME" \
    -H "Content-Type: application/json" \
    -d "{\"policies\": $(printf '%s' "$new_policies" | jq -Rs .)}"
log SUCCESS "policy attached"

log SUCCESS "read access granted — '$USERNAME' → '${KV_PATH}/'"
log INFO "user   : $USERNAME"
log INFO "policy : $POLICY_NAME"
log INFO "grants : ${KV_PATH}/data/* read,list  |  ${KV_PATH}/metadata/* list"
