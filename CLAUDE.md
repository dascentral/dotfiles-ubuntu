# CLAUDE.md

Personal dotfiles and infrastructure-as-text for Ubuntu servers running Laravel applications.

## Layout

- `provision/setup.sh`: idempotent system customization entrypoint (sources modules from `provision/system/`, `provision/software/`, and `provision/shell/`). Invoked day-to-day via `bin/dotfiles`.
- `provision/system/`: base system modules: `update.sh`, `utilities.sh`, `defaults.sh`, `security.sh`.
- `provision/shell/`: your shell environment: `zsh.sh` installs zsh, Oh My Zsh, and plugins, and symlinks the dotfiles in `shell/`.
- `provision/software/`: one module per piece of software: `composer.sh`, `mysql.sh`, `nginx.sh`, `nodejs.sh`, `redis.sh`, `supervisor.sh`. Entry scripts choose which to source.
- `provision/provision-laravel-app-server.sh`: one-shot Laravel app server provisioning (Nginx, PHP, MySQL, Redis, Supervisor, Composer). Sources modules from `provision/software/` and runs `bin/install_php`. See `provision/CLAUDE.md`.
- `provision/provision-dascentral.sh`: dascentral.com app dependencies, run after the Laravel script.
- `lib/`: shared shell library: `config.sh` (loader), `colors.sh`, `functions.sh`.
- `bin/`: user-facing commands on `PATH` (`dotfiles`, `a`, `install_php`, `validate_redis_security`, etc.).
- `shell/`: `.zshrc`, `.aliases`, plus `sudoers.d/php-fpm`.
- `legacy/`: archived reference. Don't extend.

## Script Conventions

- **Source shared helpers first:** `source "${HOME}/.dotfiles/lib/config.sh"` brings in color codes, `section`, `ok`, `abort`, `info`, `warn`, `die`, and other helpers. All `bin/` scripts and `provision/` scripts use this. `lib/functions.sh` also provides `write_if_changed`, plus `ubuntu_version`, `ubuntu_version_lt`, and `require_ubuntu` for release-specific branches.
- **Safe to re-run on a live server:** write managed config files with `write_if_changed` and restart or reload a service only when it reports a change. Install packages with `--no-upgrade`; upgrades happen only in `system/update.sh`. Read the surrounding code before adding a new step.
- **Tuning files use a `99-*` prefix** under `conf.d/` directories so they sort last and survive package updates.

## Style

- **Bash.** `set -euo pipefail` required. Quote variable expansions. Prefer `[[ ]]` over `[ ]`. Use `section`/`ok` helpers for output.
- **Markdown.** Narrative prose by default. Bullet points only for actual lists. Avoid em dashes.

## Working With Doug

Doug is a senior Laravel developer with deep familiarity with this stack. Skip beginner explanations. Lead with the recommendation and reasoning. Push back when a proposed change is wrong.
