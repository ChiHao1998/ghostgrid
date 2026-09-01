#!/usr/bin/env bash
set -e
: "${GHOSTGRID_ROOT:?must invoke via main.sh}"
source "$GHOSTGRID_ROOT/script/logger.sh"
source "$GHOSTGRID_ROOT/lib/service.sh"

smart_install mailpit docker.io/axllent/mailpit:latest \
    -p 1025:1025 \
    -p 8025:8025
log INFO "SMTP :1025  UI http://localhost:8025"
