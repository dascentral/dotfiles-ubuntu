# Provisioning

Two scripts live here:

- `setup.sh` — idempotent system customization for any Ubuntu server. Sources modular scripts from `setup/`. Safe to re-run via `bin/dotfiles`.
- `provision-laravel-app-server.sh` — one-shot Laravel app server provisioning (Nginx, PHP 8.4-FPM, MySQL 8.4 LTS, Redis, Supervisor, Composer). Run after `setup.sh`.

## Hard Constraints

These are load-bearing. Do not remove without an explicit conversation.

- **`setup.sh` targets Ubuntu (any version).** The OS guard checks for Ubuntu generically.
- **`provision-laravel-app-server.sh` targets Ubuntu 24.04 LTS only.** The OS guard is intentional. Add a parallel branch for other versions rather than weakening the guard.
- **Both must remain idempotent.** Every step checks for existing state or relies on apt's idempotence.
- **Both run as a non-root sudo user, not root.** The pre-flight check enforces this.
- **`provision-laravel-app-server.sh` gates on `~/setup-complete.log`.** Verifies `setup.sh` has completed successfully.
- **Both scripts source `lib/config.sh`** for shared `section`/`ok` helpers. Each mirrors output to its own log (`~/setup.log` and `~/provision-laravel.log`).
- **PHP-FPM, Horizon, and app files all run as the admin user (not www-data).** Deliberate choice to avoid permission issues. Don't revert the pool config.
- **MySQL 8.4 LTS from Oracle's APT repo, not Ubuntu's default.** MySQL 8.0 reached EOL in April 2026.
- **`opcache.validate_timestamps=0` is intentional.** The deploy pipeline reloads PHP-FPM after each deploy.

## Documentation Sync

`provision/README.md` and `provision/provision-laravel-app-server.sh` must stay in sync:

- Installed software list in the README's Phase 2 must match the script.
- "Tuning decisions" in the README must match values in the script's tuning blocks.
- Phase 3 post-install steps must remain accurate.

When updating one, check the other. Drift between doc and script is the most likely failure mode.

## Tuning

Opinionated defaults, each documented in `provision/README.md` under "Tuning decisions." Update the README in the same commit when changing any of these:

- Server timezone: UTC (set in `setup/system-defaults.sh`)
- journald: 500MB cap (set in `setup/system-defaults.sh`)
- Swap: configurable via `SWAP_SIZE_GB` env var, default 2 (set in `setup/system-defaults.sh`)
- OPcache: 256MB memory, 20,000 file cap, `validate_timestamps=0`
- realpath_cache: 4MB, 600s TTL
- `innodb_buffer_pool_size`: sized to detected RAM (256MB / 512MB / 35% / 40% across tiers)

Deliberately not tuned: Redis `maxmemory`, MySQL slow query log, PHP-FPM `pm.*` settings.

## Pinned Dependencies

Overridable env vars at the top of `provision-laravel-app-server.sh`:

- `PHP_VERSION` (default 8.4)
- `MYSQL_APT_CONFIG_VERSION` (default 0.8.34-1)

Overridable env vars in `setup/`:

- `SWAP_SIZE_GB` (default 2, in `system-defaults.sh`)
- `NODE_MAJOR` (default 24, in `nodejs.sh`)

If provisioning fails on the `repo.mysql.com` download, check [dev.mysql.com/downloads/repo/apt/](https://dev.mysql.com/downloads/repo/apt/) for the current version.

## Scope Boundaries

These do not belong in either script:

- **Application deploy logic** (Nginx server blocks, Supervisor configs, logrotate). Lives in each app repo's `deploy/` folder.
- **TLS certificates.** Manual post-install step; DNS must point at the droplet first.
- **SSH hardening.** Manual because automating sshd edits risks locking you out.
