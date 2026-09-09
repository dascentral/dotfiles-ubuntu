# Provisioning

`provision.sh` bootstraps a fresh Ubuntu 24.04 LTS droplet for a consolidated multi-domain Laravel application (Nginx, PHP 8.4-FPM, MySQL 8.4 LTS, Redis, Supervisor, Composer, Node.js 24). It runs once, invoked by a human after manual SSH hardening.

## Hard Constraints

These are load-bearing. Do not remove without an explicit conversation.

- **Ubuntu 24.04 LTS only.** The OS guard is intentional. Add a parallel branch for other versions rather than weakening the guard.
- **Must remain idempotent.** Every step checks for existing state or relies on apt's idempotence.
- **Runs as a non-root sudo user, not root.** The pre-flight check enforces this.
- **PHP-FPM, Horizon, and app files all run as the admin user (not www-data).** Deliberate choice to avoid permission issues. Don't revert the pool config.
- **MySQL 8.4 LTS from Oracle's APT repo, not Ubuntu's default.** MySQL 8.0 reached EOL in April 2026.
- **`opcache.validate_timestamps=0` is intentional.** The deploy pipeline reloads PHP-FPM after each deploy.
- **Self-contained.** Uses `set -euo pipefail` with its own `section`/`ok` helpers, mirroring output to `~/provision.log` via `exec > >(tee -a "$LOG_FILE") 2>&1`. Does not source `.functions`.

## Documentation Sync

`provision/README.md` and `provision/provision.sh` must stay in sync:

- Installed software list in the README's Phase 2 must match the script.
- "Tuning decisions" in the README must match values in the script's tuning blocks.
- Phase 3 post-install steps must remain accurate.

When updating one, check the other. Drift between doc and script is the most likely failure mode.

## Tuning

Opinionated defaults, each documented in `provision/README.md` under "Tuning decisions." Update the README in the same commit when changing any of these:

- Server timezone: UTC
- journald: 500MB cap
- OPcache: 256MB memory, 20,000 file cap, `validate_timestamps=0`
- realpath_cache: 4MB, 600s TTL
- `innodb_buffer_pool_size`: sized to detected RAM (256MB / 512MB / 35% / 40% across tiers)

Deliberately not tuned: Redis `maxmemory`, MySQL slow query log, PHP-FPM `pm.*` settings.

## Pinned Dependencies

Overridable env vars at the top of the script:

- `PHP_VERSION` (default 8.4)
- `NODE_MAJOR` (default 24)
- `MYSQL_APT_CONFIG_VERSION` (default 0.8.34-1)
- `SWAP_SIZE_GB` (default 2)

If provisioning fails on the `repo.mysql.com` download, check [dev.mysql.com/downloads/repo/apt/](https://dev.mysql.com/downloads/repo/apt/) for the current version.

## Scope Boundaries

These do not belong in the provisioning script:

- **Application deploy logic** (Nginx server blocks, Supervisor configs, logrotate). Lives in each app repo's `deploy/` folder.
- **TLS certificates.** Manual post-install step; DNS must point at the droplet first.
- **SSH hardening.** Manual because automating sshd edits risks locking you out.
