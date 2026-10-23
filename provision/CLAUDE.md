# Provisioning

`setup.sh` prepares any Ubuntu server and is re-run day-to-day via `bin/dotfiles`. `provision-laravel-app-server.sh` runs once after it, and `provision-dascentral.sh` runs once after that. `provision/README.md` is the human-facing guide and documents every tuning value, overridable setting, and release difference.

## Hard Constraints

These are load-bearing. Do not remove without an explicit conversation.

- **`setup.sh` targets Ubuntu (any version).** The OS guard checks for Ubuntu generically.
- **`provision-laravel-app-server.sh` and `provision-dascentral.sh` support Ubuntu 22.04, 24.04, and 26.04 LTS only.** `require_ubuntu` enforces the list. To add a release, branch on `ubuntu_version_lt` where behavior differs rather than weakening the guard.
- **All scripts are idempotent and run as a non-root sudo user.**
- **Each script gates on the one before it.** `provision-laravel-app-server.sh` requires `~/logs/setup-complete.log`, and `provision-dascentral.sh` requires the Laravel log.
- **All scripts source `lib/config.sh`** for shared helpers and log paths. Logs and completion markers live under `~/logs`; each run replaces its previous log.
- **PHP-FPM, Horizon, and app files all run as the admin user (not www-data).** Deliberate choice to avoid permission issues. Don't revert the pool config.
- **MySQL 8.4 LTS everywhere.** 22.04 and 24.04 install from Oracle's APT repo because their default is 8.0, which reached EOL in April 2026. 26.04 uses Ubuntu's own 8.4 package, since Oracle's `mysql-apt-config` does not support it; the script sets the root password so behavior matches the Oracle path.
- **`opcache.validate_timestamps=0` is intentional.** The deploy pipeline reloads PHP-FPM after each deploy.

## Documentation Sync

`provision/README.md` must match the scripts: the Phase 2 software list and overridable settings, the "Tuning decisions" values, the "Release differences" section, and the Phase 3 post-install steps. Update the README in the same commit as any script change it describes. Drift between doc and script is the most likely failure mode.

## Scope Boundaries

These do not belong in the provisioning scripts:

- **Application deploy logic** (Nginx server blocks, Supervisor configs, logrotate). Lives in each app repo's `deploy/` folder.
- **TLS certificates.** Manual post-install step; DNS must point at the droplet first.
- **SSH hardening.** Manual because automating sshd edits risks locking you out.
