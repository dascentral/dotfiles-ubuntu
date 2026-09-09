# CLAUDE.md

Personal dotfiles and infrastructure-as-text for Ubuntu servers running Laravel applications.

## Routing

New server setup or provisioning logic goes in `provision/`. Touch the legacy `install/` scripts only when explicitly maintaining that flow. See [legacy script details](docs/legacy.md) when working on them.

## Layout

- `provision/` — modern Ubuntu 24.04 provisioning script + long-form how-to README.
- `install.sh` + `install/*.sh` — legacy one-shot installers.
- `maintain/*.sh` — recurring updates invoked by `bin/dotfiles`.
- `bin/` — user-facing commands on `PATH` (`dotfiles`, `laravel-site`, `createdb`, `validate_redis_security`, etc.).
- `shell/` — `.zshrc`, `.aliases`, `.functions`, `.helpers`, plus `sudoers.d/php-fpm`.
- `legacy/` — archived reference. Don't extend.

## Script Conventions

- **Source shared helpers first:** `source ${HOME}/.dotfiles/shell/.functions` brings in color codes, `abort`, `info`, `warn`, `die`, and predicate helpers (`nginx_installed`, `laravel_application_root`, etc.). Use these instead of reimplementing. Exception: `provision.sh` is self-contained (see `provision/CLAUDE.md`).
- **Idempotency by file probe:** legacy install scripts check `[ ! -e "/usr/bin/foo" ]` before installing. `provision.sh` uses different strategies per step; read the surrounding code before adding a new one.
- **Tuning files use a `99-*` prefix** under `conf.d/` directories so they sort last and survive package updates.

## Style

- **Bash.** `set -euo pipefail` required. Quote variable expansions. Prefer `[[ ]]` over `[ ]`. Use `section`/`ok` helpers for output in provision.sh; shared helpers elsewhere.
- **Markdown.** Narrative prose by default. Bullet points only for actual lists. Avoid em dashes.

## Working With Doug

Doug is a senior Laravel developer with deep familiarity with this stack. Skip beginner explanations. Lead with the recommendation and reasoning. Push back when a proposed change is wrong.
