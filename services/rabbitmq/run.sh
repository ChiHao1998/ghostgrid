#!/usr/bin/env bash
set -e
: "${GHOSTGRID_ROOT:?must invoke via main.sh}"
source "$GHOSTGRID_ROOT/script/logger.sh"
source "$GHOSTGRID_ROOT/lib/service.sh"

smart_install rabbitmq docker.io/library/rabbitmq:3-management \
    -p 5672:5672 \
    -p 15672:15672
log INFO "AMQP :5672  UI http://localhost:15672"
