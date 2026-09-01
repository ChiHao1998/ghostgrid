#!/usr/bin/env bash
set -e
: "${GHOSTGRID_ROOT:?must invoke via main.sh}"
source "$GHOSTGRID_ROOT/script/logger.sh"
source "$GHOSTGRID_ROOT/lib/service.sh"

DATA_DIR="$HOME/.postgres"
mkdir -p "$DATA_DIR"
smart_install postgres docker.io/library/postgres:16 \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=postgres \
    -p 5432:5432 \
    -v "$DATA_DIR:/var/lib/postgresql/data"
log INFO ":5432  data $DATA_DIR"
