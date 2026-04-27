# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

This repository contains my personal dotfiles and infrastructure-as-text for Ubuntu servers running Laravel applications.

## Server Provisioning

The `provision/` folder contains a documented procedure and bash script for bootstrapping a fresh Ubuntu 24.04 LTS droplet to host a consolidated multi-domain Laravel application (Nginx, PHP 8.4-FPM, MySQL 8.4 LTS, Redis, Supervisor, Composer, Node.js 24).

The script is run once on a freshly created droplet, after manual SSH hardening. It is not run by any automation; a human invokes it.

### Hard Constraints on `provision/provision.sh`

These are load-bearing and should not be removed without an explicit conversation:

- **Targets Ubuntu 24.04 LTS only.** The OS guard at the top of the script is intentional. If support for another version is needed, add a parallel branch rather than weakening the guard.
- **Must remain idempotent.** Re-running the script on a partially-provisioned host must be safe. Every install step either checks for existing state or relies on apt's own idempotence. Preserve this when adding new sections.
- **Must run as a non-root sudo user, not as root.** The pre-flight check enforces this.
- **PHP-FPM, Horizon, and application files all run as the same admin user (not www-data).** This is a deliberate choice to avoid permission whack-a-mole. Don't "helpfully" revert the pool config to `www-data`.
- **MySQL 8.4 LTS from Oracle's APT repo, not Ubuntu's default 8.0.** MySQL 8.0 reached EOL in April 2026. Do not switch the script to `apt install mysql-server` from default repos.
- `opcache.validate_timestamps=0` is intentional. It requires the deploy pipeline to reload PHP-FPM after each deploy. This trade-off is documented in the README and is the right call for this workload. Don't flip it back to 1 to "fix" cache staleness.
- **Tuning files use `99-*` filenames in `conf.d/` directories.** This makes them easy to find and override, and prevents collisions with package-managed configs.

### Tuning rationale

The script applies opinionated defaults. Each one has a reason documented in `provision/README.md` under "Tuning decisions." When changing any of these, update the README's rationale section in the same commit so the two stay in sync:

- Server timezone pinned to UTC
- journald capped at 500MB
- OPcache memory 256MB, file cap 20,000, `validate_timestamps=0`
- realpath_cache 4MB, 600s TTL
- `innodb_buffer_pool_size` sized to detected RAM (256MB / 512MB / 35% / 40% across tiers)

Things deliberately not tuned: Redis `maxmemory` (needs cache/queue DB separation first), MySQL slow query log (observability concern, not setup), PHP-FPM `pm.*` settings (depend on measured per-process footprint).

### Documentation Sync

`provision/README.md` and `provision/provision.sh` must stay in sync. Specifically:

- The list of installed software in the README's Phase 2 must match what the script actually installs.
- The "Tuning decisions" section in the README must match the actual values in the script's tuning ini/cnf blocks.
- The post-install steps in Phase 3 must remain accurate (FPM pool user change, FPM reload requirement, certbot path, etc.).

When updating one, check the other. A drift between doc and script is the most likely failure mode for this repo.

### Versioning of Pinned Dependencies

Several externally-versioned dependencies are pinned at the top of the script as overridable env vars:

- `PHP_VERSION` (default 8.4)
- `NODE_MAJOR` (default 24)
- `MYSQL_APT_CONFIG_VERSION` (default 0.8.34-1)
- `SWAP_SIZE_GB` (default 2)

The MySQL APT config version is the most likely to drift; if a provisioning run fails on the `repo.mysql.com` download, check [https://dev.mysql.com/downloads/repo/apt/](https://dev.mysql.com/downloads/repo/apt/) for the current version and update the default.

## Legacy Scripts

The provisioning script was created in April 2026 and replaces many of the existing installation scripts. Work remains to cull the legacy functionality that is no longer needed, but do not conflate the two sets of code.

The **legacy / day-to-day** scripts include `install.sh`, `bin/dotfiles`, `install/`, `maintain/`. They assume the repo is cloned to `~/.dotfiles`. `install.sh` runs interactive prompts and installs an older PHP set (8.0–8.3). `bin/dotfiles` is the recurring maintenance entrypoint (git pull + apt upgrade + composer + oh-my-zsh refresh).

When asked to add new server setup or provisioning logic, default to the `provision/` path. Touch the legacy `install/` scripts only when explicitly maintaining that flow.

## Conventions Every Script Follows

- **Source the shared helpers first:** `source ${HOME}/.dotfiles/shell/.functions`. This brings in color codes plus `abort`, `info`, `warn`, `die`, and predicate helpers (`nginx_installed`, `laravel_application_root`, `git_current_branch`, `dotfiles_live_where_expected`, etc.). Use these instead of reimplementing.
- **`provision.sh` is the exception** — it's `set -euo pipefail` and self-contained with its own `section`/`ok` helpers, mirroring all output to `~/provision.log` via `exec > >(tee -a "$LOG_FILE") 2>&1`. Don't add a `source .functions` to it.
- **Idempotency by file probe:** legacy install scripts check `[ ! -e "/usr/bin/foo" ]` before installing. Match that pattern when adding new packages there. `provision.sh` uses different idempotency strategies per step (e.g., checking whether a swapfile, GPG key, or repo file already exists) — read the surrounding step before adding a new one.
- **Tuning files use a `99-*` prefix** under the relevant `conf.d/` (sshd, sysctl, php, mysql) so they sort last and survive package updates. Keep this convention.

## Layout

- `install.sh` + `install/*.sh` — legacy one-shot installers (utilities, certbot, supervisor, nginx, mysql, php{,80,81,82,83}, composer, redis, oh-my-zsh).
- `maintain/*.sh` — recurring updates invoked by `bin/dotfiles`.
- `provision/` — modern Ubuntu 24.04 provisioning script + its long-form how-to README.
- `bin/` — user-facing commands added to `PATH` via `.zshrc` (`dotfiles`, `laravel-site`, `laravel-storage`, `createdb`, `permissions_reset`, `validate_redis_security`, etc.).
- `shell/` — `.zshrc`, `.aliases`, `.functions`, `.helpers`, plus `sudoers.d/php-fpm`. The `.zshrc` sources `~/.aliases-local` if present, which is the host-local override hook.
- `legacy/` — older aliases, SSL helpers, and crontab/docs kept for reference. Don't extend.

## Useful commands while working in this repo

- Run a single legacy installer locally on an Ubuntu host: `./install/<name>.sh`.
- Run the full provisioner on a fresh host: see `provision/README.md` (Phase 1 manual SSH steps must precede `./provision/provision.sh`).
- Refresh a host: `dotfiles` (resolves to `bin/dotfiles` once the repo is on `PATH`).
- Verify Redis hardening on a target host: `bin/validate_redis_security` (expects `/var/www/html/intranet/.env`).

## Style Preferences

- **Markdown.** Narrative prose by default. Bullet points only for actual lists. Avoid em dashes.
- **Bash.** `set -euo pipefail` is required. Quote variable expansions. Prefer `[[ ]]` over `[ ]`. Use the existing `section/ok` helpers for output rather than raw `echo`.
- **Comments in the script** explain why, not what. The reader can see what `apt-get install nginx` does; they can't see why the FPM pool runs as the admin user.

## What Does Not Belong Here

- Application-specific deploy logic (Nginx server blocks, Supervisor configs for Horizon, logrotate configs). Those live in each application repo's `deploy/` folder and are rsynced into place by the application's deploy pipeline. The provision script is the OS-level substrate underneath all of that.
- TLS certificate setup. Documented as a manual post-install step because it requires DNS to already point at the droplet, which won't be true at provision time.
- SSH hardening automation. Documented as manual because automating sshd config edits is the easiest way to lock yourself out of a fresh box.

## Senior-Level Expectations

Doug is a senior Laravel developer with deep familiarity with this stack. Skip beginner explanations. When suggesting changes, lead with the recommendation and the reasoning, not with background context he already has. Push back when a proposed change is wrong; don't just agree.
