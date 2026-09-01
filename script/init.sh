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

detect_distro() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release; echo "$ID"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

install_podman() {
    local distro; distro=$(detect_distro)
    case "$distro" in
        arch|manjaro)
            pacman -Sy --noconfirm podman podman-docker
            ;;
        alpine)
            apk add --no-cache podman
            ;;
        ubuntu|debian|linuxmint|pop|kali|raspbian)
            apt-get update -q
            apt-get install -y podman podman-docker
            ;;
        centos|rhel|fedora|rocky|almalinux|ol)
            dnf install -y podman podman-docker
            ;;
        *)
            log ERROR "unsupported distro for podman install: $distro"; exit 1
            ;;
    esac
}

enable_podman_socket() {
    # Podman's API socket needs to be up before service scripts can reach it via
    # $DOCKER_HOST. Runs every time (not just on fresh install) since a
    # pre-existing podman package rarely ships with the socket pre-enabled.
    # This script itself needs root (package install), but service scripts run
    # as the invoking user against their own rootless socket — so enable the
    # *user* unit ($SUDO_USER, i.e. whoever ran sudo), not the system-wide one.
    if [ -z "$SUDO_USER" ]; then
        log WARN "no SUDO_USER — skipping rootless podman.socket enable (run init.sh via sudo as a regular user)"
        return 0
    fi
    local uid; uid=$(id -u "$SUDO_USER")
    # Lets the user's systemd instance (and its podman.socket) keep running
    # without an active login session, e.g. across terminal restarts.
    loginctl enable-linger "$SUDO_USER"
    sudo -u "$SUDO_USER" XDG_RUNTIME_DIR="/run/user/$uid" \
        systemctl --user enable --now podman.socket
}

install_jq() {
    local distro; distro=$(detect_distro)
    case "$distro" in
        ubuntu|debian|linuxmint|pop|kali|raspbian)
            apt-get install -y jq ;;
        centos|rhel|fedora|rocky|almalinux|ol)
            dnf install -y jq ;;
        arch|manjaro)
            pacman -Sy --noconfirm jq ;;
        alpine)
            apk add --no-cache jq ;;
        *)
            local arch
            case "$(uname -m)" in
                x86_64)        arch="amd64" ;;
                aarch64|arm64) arch="arm64" ;;
                *)             log ERROR "unsupported arch for jq binary"; exit 1 ;;
            esac
            download "https://github.com/jqlang/jq/releases/latest/download/jq-linux-${arch}" /usr/local/bin/jq
            chmod +x /usr/local/bin/jq
            ;;
    esac
}

install_terraform() {
    local distro arch
    distro=$(detect_distro)
    case "$(uname -m)" in
        x86_64)        arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        armv7l)        arch="arm"   ;;
        *)             log ERROR "unsupported arch $(uname -m)"; exit 1 ;;
    esac

    case "$distro" in
        ubuntu|debian|linuxmint|pop|kali|raspbian)
            download https://apt.releases.hashicorp.com/gpg /tmp/hashicorp.gpg
            gpg --dearmor < /tmp/hashicorp.gpg > /usr/share/keyrings/hashicorp-archive-keyring.gpg
            rm -f /tmp/hashicorp.gpg
            # shellcheck disable=SC1091
            . /etc/os-release
            echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
                    https://apt.releases.hashicorp.com ${VERSION_CODENAME} main" \
                    > /etc/apt/sources.list.d/hashicorp.list
            apt-get update -q
            apt-get install -y terraform
            ;;
        centos|rhel|fedora|rocky|almalinux|ol)
            dnf install -y dnf-plugins-core
            dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
            dnf install -y terraform
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm terraform
            ;;
        alpine)
            apk add --no-cache terraform
            ;;
        *)
            local ver="1.9.5"
            local url="https://releases.hashicorp.com/terraform/${ver}/terraform_${ver}_linux_${arch}.zip"
            download "$url" /tmp/terraform.zip
            if has unzip; then
                unzip -o /tmp/terraform.zip terraform -d /usr/local/bin
            else
                python3 -c "import zipfile,sys; zipfile.ZipFile('/tmp/terraform.zip').extract('terraform','/usr/local/bin')" \
                    2>/dev/null || busybox unzip /tmp/terraform.zip terraform -d /usr/local/bin
            fi
            chmod +x /usr/local/bin/terraform
            rm -f /tmp/terraform.zip
            ;;
    esac
}

# ── main ─────────────────────────────────────────────────────────────────────

if has podman; then
    log INFO "podman: $(podman --version)"
else
    log WARN "podman not found — installing..."
    install_podman
    log SUCCESS "podman installed — $(podman --version)"
fi
enable_podman_socket

if has terraform; then
    log INFO "terraform: $(terraform --version | head -1)"
else
    log WARN "terraform not found — installing..."
    install_terraform
    log SUCCESS "terraform installed — $(terraform --version | head -1)"
fi

if has jq; then
    log INFO "jq: $(jq --version)"
else
    log WARN "jq not found — installing..."
    install_jq
    log SUCCESS "jq installed — $(jq --version)"
fi
