#!/usr/bin/env bash
set -euo pipefail

: "${GHOSTGRID_ROOT:?must invoke via main.sh}"
source "$GHOSTGRID_ROOT/script/logger.sh"

PG_HOST="127.0.0.1"
PG_PORT=5432
PG_ADMIN_USER="postgres"

# ---------- 1. collect params ----------
ask_secret "postgres superuser password" PG_ADMIN_PASSWORD
ask "database name for Quartz" "" QUARTZ_DB

QUARTZ_USER="${QUARTZ_DB}_quartz"
log INFO "Quartz user: ${QUARTZ_USER}"

# ---------- 2. connectivity check ----------
log INFO "checking postgres connectivity..."
PGPASSWORD="$PG_ADMIN_PASSWORD" psql \
    -h "$PG_HOST" -p "$PG_PORT" -U "$PG_ADMIN_USER" \
    -c "SELECT 1" > /dev/null
log SUCCESS "connected to postgres"

psql_admin() {
    PGPASSWORD="$PG_ADMIN_PASSWORD" psql \
        -h "$PG_HOST" -p "$PG_PORT" -U "$PG_ADMIN_USER" \
        -d "$QUARTZ_DB" \
        -v ON_ERROR_STOP=1 \
        "$@"
}

# ---------- 3. create user (skip if exists) ----------
ROLE_EXISTS=$(PGPASSWORD="$PG_ADMIN_PASSWORD" psql \
    -h "$PG_HOST" -p "$PG_PORT" -U "$PG_ADMIN_USER" \
    -tAc "SELECT 1 FROM pg_roles WHERE rolname = '${QUARTZ_USER}'")

if [[ "$ROLE_EXISTS" == "1" ]]; then
    log INFO "role '${QUARTZ_USER}' already exists — skipping creation"
else
    ask_secret "password for Quartz user" QUARTZ_PASSWORD

    log INFO "creating user '${QUARTZ_USER}'..."
    PGPASSWORD="$PG_ADMIN_PASSWORD" psql \
        -h "$PG_HOST" -p "$PG_PORT" -U "$PG_ADMIN_USER" \
        -v ON_ERROR_STOP=1 \
        -c "CREATE ROLE \"${QUARTZ_USER}\" WITH LOGIN PASSWORD '${QUARTZ_PASSWORD}';"
    log SUCCESS "user '${QUARTZ_USER}' ready"
fi

# ---------- 4. create schema (idempotent) ----------
log INFO "creating schema 'quartz' in '${QUARTZ_DB}'..."
psql_admin -c "CREATE SCHEMA IF NOT EXISTS quartz AUTHORIZATION \"${QUARTZ_USER}\";"
log SUCCESS "schema 'quartz' ready"

# ---------- 5. grant schema privileges ----------
log INFO "granting USAGE,CREATE on schema 'quartz' to '${QUARTZ_USER}'..."
psql_admin -c "GRANT USAGE, CREATE ON SCHEMA quartz TO \"${QUARTZ_USER}\";"
log SUCCESS "privileges granted"

log INFO "database : ${QUARTZ_DB}"
log INFO "user     : ${QUARTZ_USER}"
log INFO "schema   : quartz"
