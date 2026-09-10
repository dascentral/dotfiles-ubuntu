# CLAUDE.md

Personal dotfiles and infrastructure-as-text for Ubuntu servers running Laravel applications.

## Layout

- `provision/setup.sh` — idempotent system customization entrypoint (sources modular scripts from `provision/setup/`). Invoked day-to-day via `bin/dotfiles`.
- `provision/setup/` — modular setup scripts: `system-update.sh`, `utilities.sh`, `system-defaults.sh`, `security.sh`, `nodejs.sh`, `shell.sh`.
- `provision/provision-laravel-app-server.sh` — one-shot Laravel app server provisioning (Nginx, PHP, MySQL, Redis, Supervisor, Composer). Self-contained. See `provision/CLAUDE.md`.
- `lib/` — shared shell library: `config.sh` (loader), `colors.sh`, `functions.sh`.
- `bin/` — user-facing commands on `PATH` (`dotfiles`, `a`, `validate_redis_security`, etc.).
- `shell/` — `.zshrc`, `.aliases`, plus `sudoers.d/php-fpm`.
- `legacy/` — archived reference. Don't extend.

## Script Conventions

- **Source shared helpers first:** `source "${HOME}/.dotfiles/lib/config.sh"` brings in color codes, `section`, `ok`, `abort`, `info`, `warn`, `die`, and other helpers. All `bin/` scripts and `provision/setup.sh` use this. Exception: `provision-laravel-app-server.sh` is self-contained (see `provision/CLAUDE.md`).
- **Idempotency:** each setup module is safe to re-run. Read the surrounding code before adding a new step.
- **Tuning files use a `99-*` prefix** under `conf.d/` directories so they sort last and survive package updates.

## Style

- **Bash.** `set -euo pipefail` required. Quote variable expansions. Prefer `[[ ]]` over `[ ]`. Use `section`/`ok` helpers for output.
- **Markdown.** Narrative prose by default. Bullet points only for actual lists. Avoid em dashes.

## Working With Doug

Doug is a senior Laravel developer with deep familiarity with this stack. Skip beginner explanations. Lead with the recommendation and reasoning. Push back when a proposed change is wrong.
