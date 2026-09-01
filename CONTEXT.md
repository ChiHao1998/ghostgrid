# CONTEXT.md — ghostgrid-v2

## What it is

Personal tool. Replaces memorizing Podman/Terraform commands to set up local dev services (postgres, vault, rabbitmq, mailpit) on a new machine. Bash TUI — single entry: `bash main.sh`.

**Not** a team onboarding tool. Opinionated defaults (`$HOME/.postgres`, `$HOME/.vault`) are intentional.

---

## Domain language

| Term | Meaning |
|------|---------|
| **service** | Infra component (e.g. `postgres`). Defined by `services/<name>/`. |
| **install** | Primary action: run `services/<name>/run.sh`. Creates container via Terraform if absent, starts if stopped. |
| **script** | Optional sub-action: any `.sh` in `services/<name>/script/`. Shown in action menu after install. Owned by *consumer* — scripts live under the service that needs them, even if they touch another service (e.g. postgres owns its Vault integration scripts). |
| **absent** | Container state: never created. Triggers `terraform apply`. |
| **flowing output** | TUI design constraint: no alternate screen, no fixed regions. Output scrolls naturally. Menus redraw inline. |
| **smart-install** | Pattern in every `run.sh`: inspect container state → route to start/apply/log. Idempotent. Impl as `smart_install CONTAINER TF_DIR [TF_VAR_ARGS...]` in `lib/service.sh`. |
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
  install/        ← Terraform root (all services use this subdirectory)
    main.tf
    variables.tf
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
- Terraform: `services/mailpit/install/`
- No `variables.tf` — no runtime vars needed

### postgres
- Image: `postgres:16`
- Port: `:5432`
- Data: `$HOME/.postgres` (host volume)
- Terraform: `services/postgres/install/` (subdirectory)
- Runtime vars: `-var="data_dir=$DATA_DIR"` passed at apply
- Sub-scripts:
  - `create-quartz-role.sh` — creates DB user + schema for Quartz scheduler (interactive)
  - `vault-create-database-engine.sh` — configures Vault database secrets engine for postgres
  - `vault-create-role.sh` — creates Vault dynamic DB role with TTL-scoped creds

### rabbitmq
- Image: `rabbitmq:3-management`
- Ports: AMQP `:5672`, UI `:15672`
- Terraform: `services/rabbitmq/install/`
- No `variables.tf`

### vault
- Image: `hashicorp/vault:latest`
- Port: `:8200`
- Data: `$HOME/.vault` (host volume)
- Config: `services/vault/config/` → mounted at `/vault/config`
- Requires `IPC_LOCK` capability
- Terraform: `services/vault/install/` (subdirectory)
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

### Terraform vars at runtime
Shell vars (`$DATA_DIR`, `$PG_USER`, etc.) passed via `-var=` at `apply` time, not baked into `.tf`. Same plan works across users/environments.

### sudo scope
`main.sh` runs unprivileged. It internally elevates only its own call to `script/init.sh` (Podman + Terraform install, always via `sudo bash script/init.sh`). Service `run.sh` scripts run as invoking user against podman's *rootless* per-user socket (no sudo inside `tui_run_service`); `init.sh` enables that socket for `$SUDO_USER`, not a system-wide rootful one.

### log_prompt writes to /dev/tty
`log_prompt` uses `>/dev/tty` so prompts appear even when stdout piped. `read` in sub-scripts uses `</dev/tty` same reason.

---

## Adding a service checklist

1. `services/<name>/run.sh` — call `smart_install CONTAINER "$SCRIPT_DIR/install" [TF_VAR_ARGS...]`; do pre-apply setup (e.g. `mkdir -p`) before call
2. `services/<name>/install/main.tf` — Docker provider config (talks to Podman via `$DOCKER_HOST`, see `lib/service.sh`)
3. If runtime vars needed: `variables.tf` + trailing `-var=` args to `smart_install`
4. Optional: `services/<name>/script/*.sh` for post-install ops; source via `$GHOSTGRID_ROOT`
5. All scripts begin with `: "${GHOSTGRID_ROOT:?must invoke via main.sh}"`