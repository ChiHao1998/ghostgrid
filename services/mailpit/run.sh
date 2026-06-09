#!/usr/bin/env bash
set -e
: "${GHOSTGRID_ROOT:?must invoke via main.sh}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$GHOSTGRID_ROOT/script/logger.sh"
source "$GHOSTGRID_ROOT/lib/service.sh"

run_service "mailpit" "$SCRIPT_DIR/install"
log INFO "SMTP :1025  UI http://localhost:8025"
