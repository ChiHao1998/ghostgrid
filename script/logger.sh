#!/usr/bin/env bash

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date +"%H:%M:%S")

    local color reset="\033[0m"
    case "$level" in
        INFO)    color="\033[0;34m";;
        SUCCESS) color="\033[1;32m";;
        WARN)    color="\033[1;33m";;
        ERROR)   color="\033[1;31m";;
        *)       color="\033[0m";;
    esac

    printf "${color}%s  %s${reset}\n" "$timestamp" "$message"
}

log_prompt() {
    local message="$1"
    local timestamp
    timestamp=$(date +"%H:%M:%S")
    printf "  \033[2m%s\033[0m  %s" "$timestamp" "$message" >/dev/tty
}

ask() {
    local label="$1" default="$2"
    local -n __ask_ref="$3"
    log_prompt "$label${default:+ (default: $default)}: "
    read -r __ask_ref </dev/tty
    __ask_ref="${__ask_ref:-$default}"
}

ask_secret() {
    local label="$1"
    local -n __ask_ref="$2"
    log_prompt "$label: "
    read -rs __ask_ref </dev/tty
    printf '\n' >/dev/tty
}
