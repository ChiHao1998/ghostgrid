#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=logger.sh
source "$SCRIPT_DIR/logger.sh"

has() { command -v "$1" &>/dev/null; }

download() {
    local url="$1" dest="$2"
    if has curl; then
        curl -fsSL "$url" -o "$dest"
    elif has wget; then
        wget -qO "$dest" "$url"
    else
        log ERROR "curl or wget not found"; exit 1
    fi
}

install_jq() {
    # Static binary straight from upstream — same command on every distro, no
    # package-manager branching needed.
    local arch
    case "$(uname -m)" in
        x86_64)        arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)             log ERROR "unsupported arch for jq binary"; exit 1 ;;
    esac
    download "https://github.com/jqlang/jq/releases/latest/download/jq-linux-${arch}" /usr/local/bin/jq
    chmod +x /usr/local/bin/jq
}

# ── main ─────────────────────────────────────────────────────────────────────

if has podman; then
    log INFO "podman: $(podman --version)"
else
    log ERROR "podman not found."
    log ERROR "install it yourself for your OS/distro — https://podman.io/docs/installation — then re-run: sudo bash script/init.sh"
    exit 1
fi

if has jq; then
    log INFO "jq: $(jq --version)"
else
    log WARN "jq not found — installing..."
    install_jq
    log SUCCESS "jq installed — $(jq --version)"
fi
