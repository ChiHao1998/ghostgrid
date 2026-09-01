# CLAUDE.md

ghostgrid = bash TUI bootstraps local infra (mailpit, postgres, rabbitmq, vault) via Podman.

CONTEXT.md: arch, domain lang, service inventory, add-service checklist.

## Running

```bash
bash main.sh                # launch TUI (self-elevates via sudo for init.sh only) — refuses to run as root
sudo bash script/init.sh    # check podman present, install jq only
```

No build. No tests. No package manager.

## Key files

| File | Purpose |
|------|---------|
| `main.sh` | Entry, service discovery, main loop |
| `script/tui.sh` | Flowing TUI — header, inline menu, service output |
| `script/logger.sh` | `log()` helper |
| `script/init.sh` | Checks podman present — errors out with an install link if not, doesn't auto-install it (no clean universal method across distros); installs jq itself via static binary |
| `lib/service.sh` | `smart_install`/`smart_uninstall` shared helpers (plain `podman run`/`start`/`rm`) |
| `lib/vault.sh` | Vault API helpers |
| `services/*/run.sh` | Smart-install per service — image + `podman run` args inline |

## Pitfalls

- `main.sh` exits immediately if run as root (`$EUID -eq 0`) — it must run as the target user so containers land in that user's rootless podman storage, not root's.
- `set -e` + `(( n-- ))` exits on 0. Use `n=$(( n - 1 ))`.
- `log_prompt` / `read` in sub-scripts use `/dev/tty` — stdout may be piped.
- Service scripts run as invoking user — no sudo inside `tui_run_service`. They call the `podman` CLI directly against the user's own rootless storage (no daemon/socket to enable). `sudo podman ps` (root) won't show these containers — use plain `podman ps` as that user.
- `smart_install CONTAINER IMAGE [run-args...] [-- CMD...]` (`lib/service.sh`) — args before a bare `--` are `podman run` flags, args after become the container's command (see `services/vault/run.sh`).
