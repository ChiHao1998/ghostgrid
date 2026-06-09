# CLAUDE.md

ghostgrid = bash TUI bootstraps local infra (mailpit, postgres, rabbitmq, vault) via Docker + Terraform.

CONTEXT.md: arch, domain lang, service inventory, add-service checklist.

## Running

```bash
sudo bash main.sh          # launch TUI (requires sudo for init.sh only)
bash script/init.sh        # install docker + terraform only
```

No build. No tests. No package manager.

## Key files

| File | Purpose |
|------|---------|
| `main.sh` | Entry, service discovery, main loop |
| `script/tui.sh` | Flowing TUI — header, inline menu, service output |
| `script/logger.sh` | `log()` helper |
| `script/init.sh` | Multi-distro docker + terraform install (sudo) |
| `lib/service.sh` | `smart_install` shared helper |
| `lib/vault.sh` | Vault API helpers |
| `services/*/run.sh` | Smart-install per service |
| `services/*/install/` | Terraform config per service |

## Pitfalls

- `set -e` + `(( n-- ))` exits on 0. Use `n=$(( n - 1 ))`.
- `log_prompt` / `read` in sub-scripts use `/dev/tty` — stdout may be piped.
- Service scripts run as invoking user — no sudo inside `tui_run_service`.
- Shell vars passed via `-var=` at apply time, not baked into `.tf`.