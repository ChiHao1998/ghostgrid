```
 ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗ ██████╗ ██████╗ ██╗██████╗
██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝██╔════╝ ██╔══██╗██║██╔══██╗
██║  ███╗███████║██║   ██║███████╗   ██║   ██║  ███╗██████╔╝██║██║  ██║
██║   ██║██╔══██║██║   ██║╚════██║   ██║   ██║   ██║██╔══██╗██║██║  ██║
╚██████╔╝██║  ██║╚██████╔╝███████║   ██║   ╚██████╔╝██║  ██║██║██████╔╝
 ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝
```

Bash TUI that bootstraps local dev infra — postgres, vault, rabbitmq, mailpit — via Docker + Terraform. Single entry point, no package manager, no build step.

## Why

Replace memorizing Docker/Terraform commands on every new machine. `sudo bash main.sh`, pick a service, done.

## Requirements

- Docker
- Terraform
- Linux (multi-distro install via `script/init.sh`)

If not installed: run `bash script/init.sh` first (requires sudo), or let `main.sh` do it on first launch.

## Usage

```bash
sudo bash main.sh
```

Or install the `ghostgrid` bin (once, requires sudo):

```bash
sudo bash script/install-bin.sh
ghostgrid
```

Sudo required only for initial Docker + Terraform install. Service scripts run as invoking user.

## Services

| Service | Ports | Notes |
|---------|-------|-------|
| mailpit | SMTP `:1025`, UI `:8025` | Local mail catcher |
| postgres | `:5432` | Data at `~/.postgres` |
| rabbitmq | AMQP `:5672`, UI `:15672` | guest/guest |
| vault | `:8200` | Data at `~/.vault` |

## How it works

Service discovery: `main.sh` globs `services/*/run.sh`. Any directory with a `run.sh` appears in the menu — no hardcoded list.

Each service uses the `smart_install` pattern:

```
container absent  →  terraform apply  (create)
container stopped →  docker start
container running →  stream logs
```

Idempotent. Safe to run repeatedly.

Sub-actions (seed scripts, Vault integrations, etc.) live under `services/<name>/script/*.sh` and appear in the action menu automatically.

## Structure

```
main.sh                      entry, service discovery, main loop
script/
  tui.sh                     flowing TUI — inline menus, scrolling output
  logger.sh                  log() helper
  init.sh                    Docker + Terraform install (sudo)
lib/
  service.sh                 smart_install shared helper
  vault.sh                   Vault API helpers
services/
  <name>/
    run.sh                   smart-install entrypoint (required)
    install/                 Terraform root (main.tf, variables.tf)
    script/                  optional sub-actions
    config/                  static config (vault only)
```
