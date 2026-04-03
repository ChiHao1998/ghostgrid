#!/usr/bin/env bash
set -e

source ./script/logger.sh

log INFO "🚀 Initializing..."
sudo bash ./script/init.sh

# Infrastructure directory
INFRA_DIR="./script/infrastructure"

log INFO "📂 Searching for available infrastructure scripts in $INFRA_DIR..."

# Collect all .sh files in infrastructure directory
infra_scripts=("$INFRA_DIR"/*.sh)

if [ ${#infra_scripts[@]} -eq 0 ]; then
    log WARNING "⚠️  No infrastructure scripts found in $INFRA_DIR"
    exit 1
fi

# Build display names (strip path and .sh extension)
infra_names=()
for script in "${infra_scripts[@]}"; do
    infra_names+=("$(basename "$script" .sh)")
done

# Infinite loop until user chooses Quit
while true; do
    log INFO "❓ Please select an infrastructure to install:"
    select choice in "${infra_names[@]}" "quit"; do
        if [[ "$choice" == "quit" ]]; then
            log INFO "🏃 Exiting..."
            exit 0
        elif [[ -n "$choice" ]]; then
            # Map choice back to script path
            idx=$((REPLY-1))
            script="${infra_scripts[$idx]}"
            log INFO "▶️  Running $script..."
            bash "$script"
            break
        else
            log WARNING "⚠️  Invalid selection, please try again."
        fi
    done
done
