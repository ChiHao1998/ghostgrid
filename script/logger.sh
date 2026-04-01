#!/usr/bin/env bash

SCRIPT_NAME=$(basename "$0")
START_TIME_MS=$(date +%s%3N) # epoch in milliseconds

log() {
    local level="$1"
    local message="$2"

    # Ensure START_TIME_MS is defined (milliseconds precision)
    : "${START_TIME_MS:=$(date +%s%3N)}"

    # current timestamp (sec.millis)
    local current_time
    current_time=$(date +"%Y-%m-%d %H:%M:%S.%3N")

    # elapsed calculation
    local now_ms
    now_ms=$(date +%s%3N)
    local elapsed_ms=$(( now_ms - START_TIME_MS ))
    local elapsed_sec=$(( elapsed_ms / 1000 ))
    local elapsed_millis=$(( elapsed_ms % 1000 ))
    local elapsed="${elapsed_sec}.$(printf "%03d" $elapsed_millis)s"

    local user=$(whoami)
    local pid=$$
    local host=$(hostname)
    local os=$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || uname -s)

    # metadata columns
    local meta="[$os]\t[HOST:$host]\t[USER:$user]\t[$SCRIPT_NAME]\t[PID:$pid]\t[$current_time]\t$level\t$message\t[ELAPSED:${elapsed}]"

    echo -e "$meta" | column -t -s $'\t'
}
