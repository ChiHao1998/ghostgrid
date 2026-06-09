## What

<!-- One line: what changed. -->

## Why

<!-- Problem or gap this solves. Link issue if any. -->

## Type

- [ ] New service (`services/<name>/run.sh` + Terraform)
- [ ] Service script (sub-action under existing service)
- [ ] TUI / menu logic (`script/tui.sh`)
- [ ] Shared lib (`lib/`)
- [ ] Init / install (`script/init.sh`)
- [ ] Bug fix
- [ ] Other

## Checklist

- [ ] `sudo bash main.sh` runs without errors
- [ ] New service: follows `smart_install` pattern, state-routes correctly (absent → apply, stopped → start, running → log)
- [ ] New service: `run.sh` exists (triggers discovery), Terraform in `services/<name>/install/`
- [ ] Vars passed via `-var=` at apply time, not hardcoded in `.tf`
- [ ] Scripts use `$GHOSTGRID_ROOT/...` not relative `../` paths
- [ ] No `(( n-- ))` under `set -e` — use `n=$(( n - 1 ))`
- [ ] Any `read` / `log_prompt` calls use `/dev/tty`
- [ ] No sudo inside `services/*/run.sh` or `services/*/script/`

## Tested on

- [ ] Fresh machine (container absent → full terraform apply)
- [ ] Existing machine (container present → start / log path)
