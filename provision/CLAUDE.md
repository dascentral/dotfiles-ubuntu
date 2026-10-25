# Provisioning

`setup.sh` prepares any Ubuntu server and is re-run day-to-day via `bin/dotfiles`, including on the existing 22.04 and 24.04 servers. `provision-laravel-app-server.sh` runs after it on a new 26.04 server, and `provision-dascentral.sh` runs after that. Modules live in `system/` (base OS), `software/` (one per piece of software), and `shell/` (your zsh environment); the entry scripts decide which to source, so a module can be shared, like `software/composer.sh`. `bin/install_php` installs PHP for the Laravel script and is also run directly to add a newer PHP to existing servers. It calls `bin/tune_php`, which owns the PHP tuning values. `provision/README.md` is the human-facing guide and documents every tuning value, overridable setting, and maintenance command.

## Hard Constraints

These are load-bearing. Do not remove without an explicit conversation.

- **`setup.sh` targets Ubuntu (any version).** The OS guard checks for Ubuntu generically.
- **Only new 26.04 servers are provisioned.** `provision-laravel-app-server.sh` and `provision-dascentral.sh` guard on `require_ubuntu 26.04`. Don't add branches for older releases there.
- **`bin/install_php` supports 22.04, 24.04, and 26.04** because it maintains existing servers. It installs alongside the current PHP and never switches over: no Nginx socket changes, and the `php` CLI stays pinned to the current version.
- **Every script and module is safe to re-run on a live server.** A second run on an unchanged server changes nothing and restarts nothing. Managed config files go through `write_if_changed`, and services restart or reload only when it reports a change. Installs use `--no-upgrade`; upgrades happen only in `system/update.sh` (and `software/nodejs.sh` when `NODE_MAJOR` changes). Re-running reverts hand edits to managed files, so tune through the scripts.
- **`bin/tune_php` only tunes versions named on the command line.** Its `opcache.validate_timestamps=0` serves stale code unless deploys reload PHP-FPM, so never make it tune every installed version by default.
- **All scripts run as a non-root sudo user.**
- **Each script gates on the one before it.** `provision-laravel-app-server.sh` requires `~/logs/setup-complete.log`, and `provision-dascentral.sh` requires the Laravel log.
- **All scripts source `lib/config.sh`** for shared helpers and log paths. Logs and completion markers live under `~/logs`; each run replaces its previous log.
- **PHP-FPM, Horizon, and app files all run as the admin user (not www-data).** Deliberate choice to avoid permission issues. Don't revert the pool config.
- **MySQL 8.4 LTS from Ubuntu's 26.04 archive.** Oracle's `mysql-apt-config` does not support 26.04. The script switches root from `auth_socket` to the generated password and writes `~/.mysql_root_password` only after that succeeds.
- **`opcache.validate_timestamps=0` is intentional.** The deploy pipeline reloads PHP-FPM after each deploy.

## Documentation Sync

`provision/README.md` must match the scripts: the Phase 2 software list and overridable settings, the "Tuning decisions" values, the "Maintaining existing servers" section, and the Phase 3 post-install steps. Update the README in the same commit as any script change it describes. Drift between doc and script is the most likely failure mode.

## Scope Boundaries

These do not belong in the provisioning scripts:

- **Application deploy logic** (Nginx server blocks, Supervisor configs, logrotate). Lives in each app repo's `deploy/` folder.
- **TLS certificates.** Manual post-install step; DNS must point at the droplet first.
- **SSH hardening.** Manual because automating sshd edits risks locking you out.
