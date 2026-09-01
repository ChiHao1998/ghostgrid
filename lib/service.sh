#!/usr/bin/env bash

# Service scripts never run with sudo — podman is the invoking user's own
# rootless daemon, reached directly via the `podman` CLI (no separate host/
# socket plumbing needed).

smart_install() {
    local container="$1" image="$2"
    shift 2

    # Args before a bare `--` are `podman run` flags; args after it become
    # the container's command (e.g. vault's `server -config=...`).
    local run_args=() cmd=() in_cmd=false
    for arg in "$@"; do
        if [[ "$arg" == "--" ]]; then
            in_cmd=true
            continue
        fi
        if $in_cmd; then
            cmd+=("$arg")
        else
            run_args+=("$arg")
        fi
    done

    local state
    state=$(podman inspect --format '{{.State.Status}}' "$container" 2>/dev/null || true)
    [[ -z "$state" ]] && state="absent"

    case "$state" in
        running)
            log INFO "$container already running"
            ;;
        exited|paused|created)
            log INFO "starting stopped $container..."
            podman start "$container" > /dev/null
            log SUCCESS "$container running"
            ;;
        absent)
            log INFO "pulling $image..."
            podman pull "$image"
            log INFO "creating $container..."
            podman run -d --name "$container" --restart unless-stopped \
                "${run_args[@]}" "$image" "${cmd[@]}"
            log SUCCESS "$container running"
            ;;
    esac
}

smart_uninstall() {
    local container="$1"
    local state
    state=$(podman inspect --format '{{.State.Status}}' "$container" 2>/dev/null || true)
    if [[ -z "$state" ]]; then
        log INFO "$container already absent"
        return 0
    fi
    log INFO "removing $container..."
    podman rm -f "$container" > /dev/null
    log SUCCESS "$container removed"
}
