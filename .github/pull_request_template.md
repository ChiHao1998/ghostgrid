## What

<!-- One line: what changed. -->

## Why

<!-- Problem or gap this solves. Link issue if any. -->

## Type

- [ ] New service (`services/<name>/run.sh`)
- [ ] Service script (sub-action under existing service)
- [ ] TUI / menu logic (`script/tui.sh`)
- [ ] Shared lib (`lib/`)
- [ ] Init / install (`script/init.sh`)
- [ ] Bug fix
- [ ] Other

## Checklist

- [ ] `bash main.sh` runs without errors (no top-level sudo)
- [ ] New service: follows `smart_install` pattern, state-routes correctly (absent → create, stopped → start, running → log)
- [ ] New service: `run.sh` exists (triggers discovery), calls `smart_install CONTAINER IMAGE [podman run args...]`
- [ ] Runtime vars interpolated into `podman run` args at call time, not hardcoded
- [ ] Scripts use `$GHOSTGRID_ROOT/...` not relative `../` paths
- [ ] No `(( n-- ))` under `set -e` — use `n=$(( n - 1 ))`
- [ ] Any `read` / `log_prompt` calls use `/dev/tty`
- [ ] No sudo inside `services/*/run.sh` or `services/*/script/`

## Tested on

- [ ] Fresh machine (container absent → full `podman run`)
- [ ] Existing machine (container present → start / log path)
