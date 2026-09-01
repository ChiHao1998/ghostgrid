#!/usr/bin/env bash

# kreuzwerker/docker provider talks to whatever $DOCKER_HOST points at; default
# it to the invoking user's rootless podman socket (enabled once, per-user, by
# enable_podman_socket in script/init.sh) so service scripts never need root.
: "${DOCKER_HOST:=unix://${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock}"
export DOCKER_HOST

smart_install() {
    local container="$1" tf_dir="$2"
    shift 2

    if ! grep -q "resource \"docker_container\" \"${container}\"" "$tf_dir/main.tf" 2>/dev/null; then
        log ERROR "docker_container.$container not found in $tf_dir/main.tf"
        return 1
    fi

    local state
    state=$(podman inspect --format '{{.State.Status}}' "$container" 2>/dev/null || true)
    [[ -z "$state" ]] && state="absent"

    case "$state" in
        running)
            log INFO "$container already running"
            ;;
        exited|paused|created)
            log INFO "recreating stopped $container..."
            terraform -chdir="$tf_dir" apply -auto-approve -input=false \
                -replace="docker_container.$container" "$@"
            log SUCCESS "$container running"
            ;;
        absent)
            log INFO "initializing terraform..."
            terraform -chdir="$tf_dir" init -input=false
            log INFO "applying $container config..."
            terraform -chdir="$tf_dir" apply -auto-approve -input=false "$@"
            log SUCCESS "$container running"
            ;;
    esac
}

run_service() {
    local container="$1" tf_dir="$2" data_dir="${3:-}"
    if [[ -n "$data_dir" ]]; then
        mkdir -p "$data_dir"
        smart_install "$container" "$tf_dir" -var="data_dir=$data_dir"
    else
        smart_install "$container" "$tf_dir"
    fi
}

smart_uninstall() {
    local container="$1" tf_dir="$2"
    local state
    state=$(podman inspect --format '{{.State.Status}}' "$container" 2>/dev/null || true)
    if [[ -z "$state" ]]; then
        log INFO "$container already absent"
        return 0
    fi
    log INFO "destroying $container..."
    terraform -chdir="$tf_dir" destroy -auto-approve -input=false
    log SUCCESS "$container removed"
}
