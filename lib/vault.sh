#!/usr/bin/env bash

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"

vault_api() {
    local method="$1" path="$2"
    shift 2
    curl -sf -X "$method" \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        "${@}" \
        "$VAULT_ADDR/v1/$path"
}

vault_check_status() {
    log INFO "checking vault status..."
    local health_code
    health_code=$(curl -s -o /dev/null -w "%{http_code}" "$VAULT_ADDR/v1/sys/health" 2>/dev/null) || true
    case "$health_code" in
        200|429) log INFO "vault: unsealed and ready" ;;
        501)     log ERROR "vault: not initialized"; return 1 ;;
        503)     log ERROR "vault: sealed — unseal first"; return 1 ;;
        ""|000)  log ERROR "vault unreachable at $VAULT_ADDR"; return 1 ;;
        *)       log ERROR "vault: unexpected status $health_code"; return 1 ;;
    esac
}

vault_init_bootstrap() {
    vault_check_status
    ask_secret "vault root token" VAULT_TOKEN
}

vault_ensure_ready() {
    vault_check_status
    vault_login_admin
}

vault_ensure_userpass() {
    log INFO "checking userpass auth method..."
    if vault_api GET sys/auth | jq -e '."userpass/"' > /dev/null 2>&1; then
        log INFO "userpass already enabled — skipped"
    else
        log INFO "enabling userpass..."
        vault_api POST sys/auth/userpass \
            -H "Content-Type: application/json" \
            -d '{"type":"userpass","description":"Userpass auth method"}'
        log SUCCESS "userpass enabled"
    fi
}

vault_login_admin() {
    local user password response
    ask "admin username" "admin" user
    ask_secret "admin password" password

    log INFO "logging in as '$user'..."
    response=$(curl -sf -X POST \
        -H "Content-Type: application/json" \
        -d "{\"password\": $(printf '%s' "$password" | jq -Rs .)}" \
        "$VAULT_ADDR/v1/auth/userpass/login/$user") || {
        log ERROR "login failed — check username/password"
        return 1
    }
    VAULT_TOKEN=$(printf '%s' "$response" | jq -r '.auth.client_token')
    if [[ -z "$VAULT_TOKEN" || "$VAULT_TOKEN" == "null" ]]; then
        log ERROR "login failed — no token returned"
        return 1
    fi
    log SUCCESS "logged in as '$user'"
}

vault_user_exists() {
    local username="$1"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" -X GET \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        "$VAULT_ADDR/v1/auth/userpass/users/$username" 2>/dev/null) || true
    case "$code" in
        200)    return 0 ;;
        403)    log ERROR "insufficient permissions"; exit 1 ;;
        ""|000) log ERROR "vault unreachable"; exit 1 ;;
        *)      return 1 ;;
    esac
}

vault_mount_exists() {
    local path="$1"
    vault_api GET sys/mounts | jq -e --arg p "${path}/" '.[$p]' > /dev/null 2>&1
}

_vault_strip_path_block() {
    local policy="$1" path_key="$2"
    awk -v target="path \"$path_key\"" '
        /^path / && $0 ~ target { skip=1; next }
        skip && /^\}/ { skip=0; next }
        !skip { print }
    ' <<< "$policy"
}

_vault_get_path_caps() {
    local policy="$1" path_key="$2"
    awk -v target="path \"$path_key\"" '
        /^path / && $0 ~ target { found=1; next }
        found && /capabilities/ { gsub(/[[:space:]]/, ""); print; found=0 }
        found && /^\}/ { found=0 }
    ' <<< "$policy"
}

_vault_norm_caps() {
    printf '%s' "$1" | grep -o '"[^"]*"' | sort | tr '\n' ' '
}

vault_policy_upsert_block() {
    local policy_name="$1" new_block="$2"
    local path_key caps_line existing_policy existing_caps merged

    path_key=$(printf '%s' "$new_block" | sed -n 's/^path "\([^"]*\)".*/\1/p')
    caps_line=$(printf '%s' "$new_block" | grep 'capabilities')

    existing_policy=""
    if vault_api GET "sys/policies/acl/$policy_name" > /dev/null 2>&1; then
        existing_policy=$(vault_api GET "sys/policies/acl/$policy_name" | jq -r '.data.policy')
    fi

    existing_caps=$(_vault_get_path_caps "$existing_policy" "$path_key")

    if [[ -z "$existing_caps" ]]; then
        log INFO "  path \"$path_key\" — appending"
        merged="${existing_policy:+${existing_policy}$'\n\n'}${new_block}"
    elif [[ "$(_vault_norm_caps "$existing_caps")" == "$(_vault_norm_caps "$caps_line")" ]]; then
        log INFO "  path \"$path_key\" — up to date"
        return 0
    else
        log INFO "  path \"$path_key\" — replacing"
        merged="$(_vault_strip_path_block "$existing_policy" "$path_key")"$'\n\n'"${new_block}"
    fi

    vault_api PUT "sys/policies/acl/$policy_name" \
        -H "Content-Type: application/json" \
        -d "{\"policy\": $(printf '%s' "$merged" | jq -Rs .)}"
}
