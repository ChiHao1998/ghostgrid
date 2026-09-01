# CLAUDE.md

ghostgrid = bash TUI bootstraps local infra (mailpit, postgres, rabbitmq, vault) via Podman + Terraform.

CONTEXT.md: arch, domain lang, service inventory, add-service checklist.

## Running

```bash
bash main.sh                # launch TUI (self-elevates via sudo for init.sh only)
sudo bash script/init.sh    # install podman + terraform only
```

No build. No tests. No package manager.

## Key files

| File | Purpose |
|------|---------|
| `main.sh` | Entry, service discovery, main loop |
| `script/tui.sh` | Flowing TUI — header, inline menu, service output |
| `script/logger.sh` | `log()` helper |
| `script/init.sh` | Multi-distro podman + terraform install (sudo) |
| `lib/service.sh` | `smart_install` shared helper |
| `lib/vault.sh` | Vault API helpers |
| `services/*/run.sh` | Smart-install per service |
| `services/*/install/` | Terraform config per service |

## Pitfalls

- `set -e` + `(( n-- ))` exits on 0. Use `n=$(( n - 1 ))`.
- `log_prompt` / `read` in sub-scripts use `/dev/tty` — stdout may be piped.
- Service scripts run as invoking user — no sudo inside `tui_run_service`. They talk to podman's *rootless* per-user socket (`lib/service.sh`'s `$DOCKER_HOST`), enabled for `$SUDO_USER` by `script/init.sh`. `sudo podman ps` (root) won't show these containers — use plain `podman ps` as that user.
- Shell vars passed via `-var=` at apply time, not baked into `.tf`.
- Migrating from an older rootful install: `services/<name>/install/{.terraform,terraform.tfstate*,.terraform.lock.hcl}` may be root-owned from prior `sudo`-mode runs, which blocks rootless `terraform apply` with "permission denied" on the state lock. Fix once: `sudo chown -R "$USER": services/*/install/.terraform* services/*/install/terraform.tfstate*` (only touches dirs that exist).