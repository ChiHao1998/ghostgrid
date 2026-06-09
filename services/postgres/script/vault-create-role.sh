#!/usr/bin/env bash
set -euo pipefail
: "${GHOSTGRID_ROOT:?must invoke via main.sh}"
source "$GHOSTGRID_ROOT/script/logger.sh"
source "$GHOSTGRID_ROOT/lib/vault.sh"

vault_ensure_ready

ask "vault database engine name" "" ENGINE_NAME
ask "vault role name" "" ROLE_NAME
ask "database name (vault db_name)" "" DB_NAME
ask "default TTL" "1h" DEFAULT_TTL
ask "max TTL" "24h" MAX_TTL

log INFO "checking mounts..."
if vault_mount_exists "$ENGINE_NAME"; then
    log INFO "engine '${ENGINE_NAME}' already mounted — skipping"
else
    log INFO "enabling database engine at '${ENGINE_NAME}'..."
    vault_api POST "sys/mounts/${ENGINE_NAME}" \
        -H "Content-Type: application/json" \
        -d '{"type":"database"}'
    log SUCCESS "database engine enabled at '${ENGINE_NAME}'"
fi

CREATION_STMTS=$(jq -n \
    --arg s1 "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'" \
    --arg s2 "GRANT CONNECT ON DATABASE ${DB_NAME} TO \"{{name}}\"" \
    --arg s3 "GRANT USAGE ON SCHEMA public TO \"{{name}}\"" \
    --arg s4 "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\"" \
    --arg s5 "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\"" \
    --arg s6 "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO \"{{name}}\"" \
    --arg s7 "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO \"{{name}}\"" \
    '[$s1,$s2,$s3,$s4,$s5,$s6,$s7]')

REVOCATION_STMTS=$(jq -n \
    --arg s1 "DROP OWNED BY \"{{name}}\"" \
    --arg s2 "DROP ROLE IF EXISTS \"{{name}}\"" \
    '[$s1,$s2]')

log INFO "creating role '${ROLE_NAME}' in engine '${ENGINE_NAME}'..."
vault_api POST "${ENGINE_NAME}/roles/${ROLE_NAME}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
        --arg db         "$DB_NAME" \
        --arg ttl        "$DEFAULT_TTL" \
        --arg max_ttl    "$MAX_TTL" \
        --argjson creation    "$CREATION_STMTS" \
        --argjson revocation  "$REVOCATION_STMTS" \
        '{
            db_name: $db,
            creation_statements: $creation,
            revocation_statements: $revocation,
            default_ttl: $ttl,
            max_ttl: $max_ttl
        }')"

log SUCCESS "vault database role '${ROLE_NAME}' created"
log INFO "engine : ${ENGINE_NAME}"
log INFO "role   : ${ROLE_NAME}"
log INFO "addr   : $VAULT_ADDR/ui/vault/secrets/${ENGINE_NAME}"
