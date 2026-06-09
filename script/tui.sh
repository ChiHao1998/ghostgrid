#!/usr/bin/env bash

KEY_INPUT=""

tui_init() {
    trap tui_cleanup EXIT INT TERM
}

tui_cleanup() {
    tput cnorm
}

tui_draw_header() {
    local count="$1"
    local version
    version=$(git -C "$(dirname "$(realpath "$0")")" describe --tags --abbrev=0 2>/dev/null || echo "0")

    echo -e "  \033[2m░██████╗░██╗  ██╗░█████╗░░██████╗████████╗ ██████╗░ ██████╗░██╗██████╗░\033[0m"
    echo -e "  \033[2m██╔════╝░██║  ██║██╔══██╗██╔════╝╚══██╔══╝██╔════╝░██╔══██╗██║██╔══██╗\033[0m"
    echo -e "  \033[2m██║░░██╗░███████║██║░░██║╚█████╗░   ██║   ██║░░██╗░██████╔╝██║██║░░██║\033[0m"
    echo -e "  \033[2m██║░░╚██╗██╔══██║██║░░██║ ╚═══██╗   ██║   ██║░░╚██╗██╔══██╗██║██║░░██║\033[0m"
    echo -e "  \033[2m╚██████╔╝██║  ██║╚█████╔╝██████╔╝   ██║   ╚██████╔╝██║  ██║██║██████╔╝\033[0m"
    echo -e "  \033[2m░╚═════╝ ╚═╝  ╚═╝ ╚════╝ ╚═════╝    ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝\033[0m"
    echo ""
    echo -e "  \033[2mLocal Infrastructure Bootstrapper  ·  version ${version}  ·  ${count} services\033[0m"
    echo -e "  \033[2m───────────────────────────────────────────────────────────────\033[0m"
    echo ""
}

tui_draw_menu() {
    local -n _result="$1"
    local label="$2"
    shift 2
    local options=("$@")
    local selected=0
    local count=${#options[@]}
    local menu_lines=$(( count + 2 ))  # label + options + hint

    _render() {
        printf '\r\033[K  %s\n' "$label"
        local i
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                printf '\r\033[K  \033[1;32m>\033[0m %s\n' "${options[$i]}"
            else
                printf '\r\033[K    \033[2m%s\033[0m\n' "${options[$i]}"
            fi
        done
        printf '\r\033[K  \033[2m↑↓ navigate  ·  Enter select  ·  ESC back\033[0m\n'
    }

    _clear_menu() {
        printf '\033[%dA' "$menu_lines"
        local i
        for ((i=0; i<menu_lines; i++)); do
            printf '\033[2K\n'
        done
        printf '\033[%dA' "$menu_lines"
    }

    _read_key() {
        local c
        IFS= read -rsn1 KEY_INPUT
        [[ "$KEY_INPUT" != $'\x1b' ]] && return
        KEY_INPUT=$'\x1b'
        while IFS= read -rsn1 -t 0.05 c 2>/dev/null; do
            KEY_INPUT+="$c"
            [[ "$c" =~ [A-Za-z~] ]] && break
        done
    }

    tput civis
    _render
    while true; do
        _read_key
        case "$KEY_INPUT" in
            $'\x1b[A')
                [[ $selected -gt 0 ]] && selected=$(( selected - 1 )) ;;
            $'\x1b[B')
                [[ $selected -lt $(( count - 1 )) ]] && selected=$(( selected + 1 )) ;;
            $'\x1b')
                _clear_menu
                tput cnorm
                _result="quit"; return ;;
            '' | $'\r')
                _clear_menu
                tput cnorm
                _result="${options[$selected]}"; return ;;
        esac
        printf '\033[%dA' "$menu_lines"
        _render
    done
}

tui_run_service() {
    local script="$1"
    local line
    while IFS= read -r line; do
        line="${line/$'\r'/}"
        printf '  %s\n' "$line"
    done < <(bash "$script" 2>&1)
    printf '  \033[2m%s\033[0m\n\n' "────────────────────────────────────────────────────────────────"
}
