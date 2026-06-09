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

install_docker() {
    local distro; distro=$(detect_distro)
    case "$distro" in
        arch|manjaro)
            pacman -Sy --noconfirm docker
            systemctl enable --now docker
            ;;
        alpine)
            apk add --no-cache docker
            rc-update add docker boot
            service docker start
            ;;
        *)
            download https://get.docker.com /tmp/get-docker.sh
            sh /tmp/get-docker.sh
            rm -f /tmp/get-docker.sh
            ;;
    esac
    [ -n "$SUDO_USER" ] && usermod -aG docker "$SUDO_USER" 2>/dev/null || true
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

if has docker; then
    log INFO "docker: $(docker --version)"
else
    log WARN "docker not found — installing..."
    install_docker
    log SUCCESS "docker installed — $(docker --version)"
fi

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
