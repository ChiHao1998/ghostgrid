```
 ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗ ██████╗ ██████╗ ██╗██████╗
██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝██╔════╝ ██╔══██╗██║██╔══██╗
██║  ███╗███████║██║   ██║███████╗   ██║   ██║  ███╗██████╔╝██║██║  ██║
██║   ██║██╔══██║██║   ██║╚════██║   ██║   ██║   ██║██╔══██╗██║██║  ██║
╚██████╔╝██║  ██║╚██████╔╝███████║   ██║   ╚██████╔╝██║  ██║██║██████╔╝
 ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝
```

Bash TUI that bootstraps local dev infra — postgres, vault, rabbitmq, mailpit — via Podman. Single entry point, no package manager, no build step.

## Why

Replace memorizing Podman commands on every new machine. `bash main.sh`, pick a service, done.

## Requirements

- Podman
- Linux

`script/init.sh` checks for Podman (and installs `jq` itself if missing) — it does not install Podman for you, since there's no single install method that works the same across every distro. If Podman is missing, install it yourself ([podman.io/docs/installation](https://podman.io/docs/installation)) then run `sudo bash script/init.sh`, or just let `main.sh` run the same check on first launch.

## Usage

```bash
bash main.sh
```

Run it as your normal user — never with `sudo`. `main.sh` refuses to start as root (containers must land in your own rootless podman storage, not root's); it elevates only its own internal call to `script/init.sh`.

Or install the `ghostgrid` bin (once, requires sudo):

```bash
sudo bash script/install-bin.sh
ghostgrid
```

`main.sh` runs unprivileged and internally elevates (`sudo`) only its own call to `script/init.sh` for the initial Podman install. Services run rootless — containers live under your user's own podman storage, not root's.

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
container absent  →  podman run  (create)
container stopped →  podman start
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
  init.sh                    Checks podman present, installs jq (sudo)
lib/
  service.sh                 smart_install shared helper
  vault.sh                   Vault API helpers
services/
  <name>/
    run.sh                   smart-install entrypoint (required) — image + podman run args
    script/                  optional sub-actions
    config/                  static config (vault only)
```
