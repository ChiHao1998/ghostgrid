# CONTEXT.md — ghostgrid-v2

## What it is

Personal tool. Replaces memorizing Podman commands to set up local dev services (postgres, vault, rabbitmq, mailpit) on a new machine. Bash TUI — single entry: `bash main.sh`.

**Not** a team onboarding tool. Opinionated defaults (`$HOME/.postgres`, `$HOME/.vault`) are intentional.

---

## Domain language

| Term | Meaning |
|------|---------|
| **service** | Infra component (e.g. `postgres`). Defined by `services/<name>/`. |
| **install** | Primary action: run `services/<name>/run.sh`. Creates container via `podman run` if absent, starts if stopped. |
| **script** | Optional sub-action: any `.sh` in `services/<name>/script/`. Shown in action menu after install. Owned by *consumer* — scripts live under the service that needs them, even if they touch another service (e.g. postgres owns its Vault integration scripts). |
| **absent** | Container state: never created. Triggers `podman run` (create). |
| **flowing output** | TUI design constraint: no alternate screen, no fixed regions. Output scrolls naturally. Menus redraw inline. |
| **smart-install** | Pattern in every `run.sh`: inspect container state → route to create/start/log. Idempotent. Impl as `smart_install CONTAINER IMAGE [run-args...] [-- CMD...]` in `lib/service.sh`. |
| **GHOSTGRID_ROOT** | Env var exported by `main.sh`. Absolute path to repo root. All scripts source shared libs via `$GHOSTGRID_ROOT/...` not relative `../` chains. |

---

## Architecture

### Entry flow

```
main.sh
  ├─ source script/logger.sh
  ├─ source script/tui.sh
  ├─ scan services/*/run.sh → service_names[], service_map[]
  ├─ tui_init + tui_draw_header   ← prints once, scrolls away
  ├─ pipe sudo script/init.sh 2>&1 through 2-space indent loop
  └─ main loop:
       tui_draw_menu → service select
       tui_draw_menu → action select (install | script/* | back)
       tui_run_service → pipe bash "$script" 2>&1 with 2-space indent
```

### TUI design (script/tui.sh)

- No `smcup`/`rmcup` (no alternate screen). No `csr` (no scroll region).
- Header prints once to stdout, scrolls away on scroll-up.
- Menu: renders inline. `_clear_menu` moves cursor up N, clears N lines, moves up N again.
- `menu_lines = count + 2` (label line + N options + hint line).
- `tui_draw_menu result_var "label" opt1 opt2 ...` — returns via `local -n` nameref.
- Key reading: `read -rsn1` + ESC-sequence drain loop with `-t 0.05`.
- ESC → `_result="quit"`. Enter → `_result="${options[$selected]}"`.

### Service structure

```
services/<name>/
  run.sh          ← smart-install (required — presence triggers discovery)
                    calls smart_install CONTAINER IMAGE [podman run args...]
  config/         ← static config mounted into container (vault only)
  script/         ← optional sub-actions shown in action menu
    *.sh
```

### lib/vault.sh

Shared lib sourced by vault scripts and postgres vault-integration scripts.

| Function | Purpose |
|----------|---------|
| `vault_api METHOD PATH [curl-args...]` | Authenticated curl wrapper. Uses `$VAULT_TOKEN` + `$VAULT_ADDR`. |
| `vault_check_status` | HTTP health check. Maps codes to states: 200/429=ready, 501=uninit, 503=sealed. |
| `vault_login_admin` | Interactive userpass login. Prompts user/pass, sets `$VAULT_TOKEN`. |
| `vault_init_bootstrap` | Status check + root token prompt. Entry point for bootstrap scripts that run before the admin user exists. |
| `vault_ensure_ready` | Calls `vault_check_status` then `vault_login_admin`. Entry point for all vault scripts using userpass auth. |
| `vault_ensure_userpass` | Idempotent: enables userpass auth method if not already enabled. |

---

## Services

### mailpit
- Image: `axllent/mailpit:latest`
- Ports: SMTP `:1025`, UI `:8025`
- `services/mailpit/run.sh` — no volumes/vars needed

### postgres
- Image: `postgres:16`
- Port: `:5432`
- Data: `$HOME/.postgres` (host volume)
- `services/postgres/run.sh` — `mkdir -p` the data dir, then `-v "$DATA_DIR:/var/lib/postgresql/data"`
- Sub-scripts:
  - `create-quartz-role.sh` — creates DB user + schema for Quartz scheduler (interactive)
  - `vault-create-database-engine.sh` — configures Vault database secrets engine for postgres
  - `vault-create-role.sh` — creates Vault dynamic DB role with TTL-scoped creds

### rabbitmq
- Image: `rabbitmq:3-management`
- Ports: AMQP `:5672`, UI `:15672`
- `services/rabbitmq/run.sh` — no volumes/vars needed

### vault
- Image: `hashicorp/vault:latest`
- Port: `:8200`
- Data: `$HOME/.vault` (host volume)
- Config: `services/vault/config/` → mounted at `/vault/config`
- Requires `IPC_LOCK` capability (`--cap-add IPC_LOCK`)
- Command: `vault server -config=/vault/config/vault-config.json`, passed after `--` to `smart_install`
- Sub-scripts:
  - `create-admin.sh` — enables userpass auth, creates admin user, merges admin policy (idempotent)
  - `create-kv-engine.sh` — enables KV v2 secrets engine at given path (idempotent)
  - `create-user.sh` — creates userpass user
  - `grant-kv-read.sh` — grants read policy on KV path

---

## Key invariants / gotchas

### set -e + arithmetic
`(( n-- ))` exits code 1 when result is 0 (falsy). Never use `(( expr ))` for mutation inside `set -e` scripts. Use `n=$(( n - 1 ))`.

### Service discovery
No hardcoded service list. `main.sh` globs `services/*/run.sh`. Add `run.sh` to new dir → registers it.

### Action menu dynamics
Sub-scripts in `services/<name>/script/*.sh` discovered at runtime. Any `.sh` dropped there appears as action option alongside `install`.

### Runtime vars
Shell vars (`$DATA_DIR`, etc.) are just interpolated into the `podman run` args passed to `smart_install` (e.g. `-v "$DATA_DIR:/var/lib/postgresql/data"`). Same `run.sh` works across users/environments since `$HOME`-relative paths are computed at call time, not hardcoded.

### sudo scope
`main.sh` refuses to run as root (`$EUID -eq 0` check near the top) — it must run as the target user so containers land in that user's own rootless podman storage, not root's. It internally elevates only its own call to `script/init.sh` (checks Podman is present, installs `jq`, always via `sudo bash script/init.sh`). Service `run.sh` scripts run as the invoking user, calling the `podman` CLI directly against that user's own rootless storage (no sudo inside `tui_run_service`, no daemon/socket to enable).

### podman install is manual
`script/init.sh` does not install Podman — there's no install method that's actually the same across every distro (unlike `jq`, which ships a static binary). It just checks `has podman` and errors out with a link if missing, leaving the "how" to the user's own OS/distro.

### log_prompt writes to /dev/tty
`log_prompt` uses `>/dev/tty` so prompts appear even when stdout piped. `read` in sub-scripts uses `</dev/tty` same reason.

---

## Adding a service checklist

1. `services/<name>/run.sh` — source `$GHOSTGRID_ROOT/lib/service.sh`, do any pre-run setup (e.g. `mkdir -p "$DATA_DIR"`), then call `smart_install CONTAINER IMAGE [podman run args...] [-- CMD...]`
2. If the image needs a non-default command (e.g. vault), append it after a bare `--`
3. Optional: `services/<name>/script/*.sh` for post-install ops; source via `$GHOSTGRID_ROOT`
4. All scripts begin with `: "${GHOSTGRID_ROOT:?must invoke via main.sh}"`