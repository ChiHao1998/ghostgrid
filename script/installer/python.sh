#!/usr/bin/env bash
set -e

install_python() {
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -y
        sudo apt-get install -y python3 python3-venv python3-pip
    elif command -v yum &>/dev/null; then
        sudo yum install -y python3 python3-venv python3-pip
    else
        echo "❌ Supported package manager not found (only apt-get or yum supported)."
        exit 1
    fi
}
