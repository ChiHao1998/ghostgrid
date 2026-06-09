#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export GHOSTGRID_ROOT="$SCRIPT_DIR"
source "$SCRIPT_DIR/script/logger.sh"
source "$SCRIPT_DIR/script/tui.sh"

SERVICES_DIR="$SCRIPT_DIR/services"
service_names=()
declare -A service_map

for dir in "$SERVICES_DIR"/*/; do
    name="$(basename "$dir")"
    script="$dir/run.sh"
    [[ ! -f "$script" ]] && continue
    if [[ ! -x "$script" ]]; then
        log WARN "service '$name': run.sh not executable — skipped"
        continue
    fi
    if [[ ! -d "${dir}install" ]]; then
        log WARN "service '$name': install/ dir missing — skipped"
        continue
    fi
    service_names+=("$name")
    service_map["$name"]="$script"
done

tui_init
tui_draw_header "${#service_names[@]}"

while IFS= read -r line; do
    line="${line/$'\r'/}"
    printf '  %s\n' "$line"
done < <(sudo bash "$SCRIPT_DIR/script/init.sh" 2>&1)
echo ""

while true; do
    choice=""
    tui_draw_menu choice "Select infrastructure:" "${service_names[@]}"

    [[ "$choice" == "quit" ]] && exit 0

    matched_script="${service_map[$choice]:-}"
    [[ -z "$matched_script" ]] && continue

    script_dir="$SERVICES_DIR/$choice/script"
    extra_scripts=()
    if [[ -d "$script_dir" ]]; then
        for f in "$script_dir"/*.sh; do
            [[ -f "$f" ]] || continue
            name="$(basename "$f" .sh)"
            extra_scripts+=("$name")
        done
    fi

    sub=""
    tui_draw_menu sub "$choice" "install" "${extra_scripts[@]}" "back"

    [[ "$sub" == "back" || "$sub" == "quit" ]] && continue

    if [[ "$sub" == "install" ]]; then
        tui_run_service "$matched_script"
    elif [[ -f "$script_dir/$sub.sh" ]]; then
        tui_run_service "$script_dir/$sub.sh"
    fi
done
