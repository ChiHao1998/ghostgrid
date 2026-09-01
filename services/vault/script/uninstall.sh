#!/usr/bin/env bash
set -e
: "${GHOSTGRID_ROOT:?must invoke via main.sh}"
source "$GHOSTGRID_ROOT/script/logger.sh"
source "$GHOSTGRID_ROOT/lib/service.sh"

smart_uninstall "vault"
