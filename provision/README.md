# How to set up an Ubuntu Server

**Last updated:** October 2026
**Target OS:** Ubuntu 26.04 LTS (Resolute Raccoon)
**Stack:** Nginx, PHP 8.4-FPM, MySQL 8.4 LTS, Redis, Supervisor

## Introduction

This document covers provisioning a hardened Ubuntu 26.04 droplet for Laravel application hosting. The bulk of the software install is automated by the companion `provision-laravel-app-server.sh` script (run after `setup.sh` has prepared the base system). Manual steps remain for anything that's risky to automate (SSH hardening) or requires per-host context (TLS certificates, application configuration).

Recommended droplet size for a Laravel workload running Horizon, Pulse, and a Vite build pipeline: 4GB RAM, 2 vCPU. The 2GB tier reliably hits OOM during `composer install` or `npm run build` once any meaningful application traffic is present.

## A note on package sources

PHP comes from Ondřej Surý's [packages.sury.org/php](https://packages.sury.org/php/) repository. His Launchpad PPA, which older servers use, does not publish for 26.04. The provision script installs his keyring package and adds the repo.

MySQL 8.4 LTS comes from Ubuntu's own archive, since 26.04 ships it natively. It's supported through 2032. Ubuntu's package leaves root on `auth_socket`, so the script switches root to `caching_sha2_password` with a generated password.

## Tuning decisions

The script applies a small set of opinionated defaults rather than leaving everything stock. Each one is here because a stock Ubuntu install is sized for "small generic web app" and a Laravel host has a slightly different profile. Every tuning file lands under a `99-*` filename in the relevant `conf.d/` directory, so they're easy to find, easy to override, and won't be clobbered by package updates.

**Server timezone pinned to UTC.** Laravel handles user-facing timezone conversion in PHP. Keeping the OS in UTC means cron, systemd timers, MySQL timestamps, and application logs all agree on what "now" means, which removes a category of debugging frustration that's hard to anticipate until you're in it.

**journald capped at 500MB.** Default behavior is to use up to 10% of the filesystem, which on a long-running droplet quietly grows into multi-gigabyte territory and is the kind of thing you only notice when disk pressure starts causing other problems.

**`vm.swappiness=10`.** The stock value of 60 lets the kernel push PHP-FPM workers and MySQL buffers out to swap while there's still free memory to reclaim from the page cache. At 10, the swap file stays a safety net against OOM kills instead of a steady source of latency.

**OPcache memory raised to 256MB and file cap raised to 20,000.** Defaults are 128MB and 10,000. Laravel's vendor tree plus your application code will exceed 10,000 files without much effort, and silent OPcache eviction shows up as inexplicable slowness rather than an obvious error.

**OPcache `validate_timestamps=0`.** The single biggest production OPcache win. PHP stops checking whether files have changed on every request. The trade-off is that deploys must reload PHP-FPM to pick up new code; without that reload, the server keeps serving the old version indefinitely. Add `sudo systemctl reload php8.4-fpm` to the post-deploy SSH commands in your GitHub Actions workflow.

**`realpath_cache_size=4M`, `ttl=600`.** Laravel does a lot of filesystem work during bootstrap (autoloading, view resolution, config loading). Stock `realpath_cache_size` is 256K, which Laravel exhausts immediately. This is one of those changes where the difference is small per request but consistent across every request.

**`innodb_buffer_pool_size` sized to detected RAM.** The MySQL default of 128MB is fine for a tutorial and painful for anything that joins. The script picks 256MB on a 1GB host, 512MB on 2GB, ~35% of RAM on 4GB, and ~40% on 8GB+, rounded down to a multiple of 128MB (InnoDB allocates the pool in 128MB chunks anyway, and rounding keeps small RAM-reporting changes after kernel updates from triggering a MySQL restart). The percentages are below the conventional 50% recommendation because this is a shared application server, not a dedicated database host; FPM workers, Redis, Horizon, and the Vite-built asset serving all need their share too.

**What's deliberately not tuned.** Redis `maxmemory` is left at default because you'd want to separate cache and queue databases before applying an eviction policy, and that's an application decision rather than a server one. MySQL slow query log is observability tooling that belongs in a follow-up tuning pass. PHP-FPM `pm` settings (`pm.max_children`, etc.) are left at distro defaults because the right values depend on how big your application's per-process footprint actually is, which is easier to measure than to guess.

## Phase 1: Initial access and SSH hardening

These steps run before the provision script and must be done manually.

### Log in as root

```bash
ssh root@[ip_address]
```

### Create an administrative user

```bash
adduser [username]
usermod -aG sudo [username]
```

### Copy your public key

From your local machine:

```bash
ssh-copy-id [username]@[ip_address]
```

Prefer `ed25519` keys over `rsa` for new keys.

### Harden sshd

On modern Ubuntu, the cleanest pattern is a drop-in file under `/etc/ssh/sshd_config.d/` rather than editing the main config. As root on the server:

```bash
cat > /etc/ssh/sshd_config.d/99-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
EOF
```

Validate and reload:

```bash
sshd -t && systemctl reload ssh
```

Open a second SSH session (as `[username]`) and confirm key-based login works _before_ closing the root session. If something is misconfigured, the open root session is your escape hatch.

## Phase 2: Run the provision script

Switch to your administrative user, clone the dotfiles repo, and run the script. The script handles:

- System updates and base utilities
- UFW firewall (OpenSSH, Nginx Full)
- Fail2Ban
- Unattended security upgrades
- A swap file sized to 2GB by default
- Node.js 24 LTS via NodeSource
- Nginx with a catch-all default server (rejects unknown Host/SNI)
- PHP 8.4 with FPM and the standard Laravel extension set, from packages.sury.org
- MySQL 8.4 LTS from Ubuntu's archive, non-interactive install
- Redis
- Supervisor
- Composer, which later `bin/dotfiles` runs keep current with `composer self-update`

The script also applies a small set of opinionated tuning defaults; see the "Tuning decisions" section below for the what and the why.

```bash
ssh [username]@[ip_address]
git clone https://github.com/dascentral/ubuntu-dotfiles.git ~/.dotfiles
cd ~/.dotfiles/provision
./setup.sh
./provision-laravel-app-server.sh
```

DigitalOcean's Ubuntu images include `git` out of the box, so the clone works on a fresh droplet. If you're ever provisioning on a more minimal image, install git first with `sudo apt-get update && sudo apt-get install -y git`.

A few settings can be overridden with environment variables when you run the scripts:

- `SWAP_SIZE_GB` (default 2) sets the swap file size in `setup.sh`.
- `NODE_MAJOR` (default 24) picks the Node.js LTS line in `setup.sh`.
- `PHP_VERSION` (default 8.4) picks the PHP line in `provision-laravel-app-server.sh` and `provision-dascentral.sh`.
- `MYSQL_ROOT_PASSWORD` (generated if unset) sets the MySQL root password.
- `APP_USER` (default `forge`) names the application user in `provision-dascentral.sh`.

Every script is safe to re-run, including on a live server. A re-run only changes what differs from the scripts, restarts a service only when its config file changed, and never upgrades packages (`bin/dotfiles` handles upgrades). If a run fails partway through, fix the cause and run it again. Re-running also puts managed files such as `99-tuning.cnf` back to what the scripts say, so make tuning changes in the scripts rather than by hand.

A randomly generated MySQL root password is written to `~/.mysql_root_password` (mode 0600). Read it and store it in 1Password before doing anything else. The script logs its full output to `~/logs/provision-laravel.log`, replacing the previous run's log.

## Phase 3: Post-install configuration

### Secure the MySQL installation

```bash
sudo mysql_secure_installation
```

Use the password from `~/.mysql_root_password`. On the first prompt, decline the validate-password component unless you actually want it (it interferes with application-generated passwords more often than it helps). Answer yes to removing the anonymous user, disallowing remote root login, removing the test database, and reloading privilege tables.

### PHP-FPM pool user

Edit `/etc/php/8.4/fpm/pool.d/www.conf` and change the `user`, `group`, `listen.owner`, and `listen.group` directives from `www-data` to `[username]`. This keeps PHP-FPM, Horizon (run by your admin user via Supervisor), and your application files all owned by the same identity, which avoids the permissions whack-a-mole that comes from mixing `www-data` and a personal user.

```bash
sudo systemctl restart php8.4-fpm
```

### Deploy pipeline: PHP-FPM reload

Because the script sets `opcache.validate_timestamps=0`, your deploy pipeline must reload PHP-FPM after each successful deploy so that new code is picked up. Add this to the post-deploy SSH commands in your GitHub Actions workflow, alongside the existing `horizon:terminate` call:

```bash
sudo systemctl reload php8.4-fpm
```

Reload (rather than restart) is graceful: in-flight requests finish on the old workers while new workers start fresh with the updated bytecode cache. The "Optional: passwordless sudo for service reloads" section below covers letting this run without an interactive password prompt.

### Nginx catch-all default server

The provision script installs a catch-all server block at `/etc/nginx/sites-available/00-catch-all` and removes the packaged default site. This block claims `default_server` on ports 80 and 443 and rejects every request that does not match a named server block:

- Plain HTTP requests to the IP (or an unknown `Host` header) get a `444` (connection closed with no response).
- TLS handshakes with an unknown or missing SNI are rejected at the handshake level via `ssl_reject_handshake on`, so Nginx never exposes a certificate for the wrong hostname.

This matters because without it, Nginx serves whichever site sorts first alphabetically to anyone who hits the droplet by IP or with a spoofed Host header. That leaks the existence of your real sites to scanners and can confuse search engine indexing.

The `00-` prefix sorts before any application server block, making it easy to spot in a directory listing. Your application server blocks should not set `default_server` on their `listen` directives; the catch-all owns that role.

### Nginx server blocks

Server blocks live in `/etc/nginx/sites-available/` with symlinks in `/etc/nginx/sites-enabled/`. Version these in your application's `deploy/nginx/` folder and rsync them into place during deploy. With a multi-domain Laravel application, expect one server block per public domain, all pointing at the same `public/` directory.

After any change:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### TLS certificates

Once DNS is pointing at the new droplet:

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d example.com -d www.example.com
```

Certbot adds its own renewal timer via `certbot.timer`, so no cron entry is needed.

### Horizon and queue workers

Supervisor configs go in `/etc/supervisor/conf.d/`. Version them in your application's `deploy/supervisor/` folder. After dropping a new config in:

```bash
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start [program-name]
```

### Logrotate

Logrotate configs are versioned in your application's `deploy/logrotate/` folder and symlinked into `/etc/logrotate.d/` during deploy.

### Optional: passwordless sudo for service reloads

If you want deploy scripts to reload PHP-FPM and Nginx without an interactive sudo prompt, add a drop-in via `visudo`:

```bash
sudo visudo -f /etc/sudoers.d/deploy-reloads
```

```
[username] ALL=NOPASSWD: /usr/bin/systemctl reload php8.4-fpm
[username] ALL=NOPASSWD: /usr/bin/systemctl reload nginx
```

Restrict the allowed commands tightly. `NOPASSWD: ALL` is convenient and a footgun.

## Verification checklist

Once the script has finished and post-install steps are done, confirm:

```bash
sudo ufw status verbose                  # OpenSSH and Nginx Full allowed
sudo systemctl status nginx              # active (running)
sudo systemctl status php8.4-fpm         # active (running)
sudo systemctl status mysql              # active (running)
sudo systemctl status redis-server       # active (running)
sudo systemctl status supervisor         # active (running)
sudo systemctl status fail2ban           # active (running)
php -v                                   # PHP 8.4.x
mysql --version                          # 8.4.x
redis-cli ping                           # PONG
composer --version                       # 2.x
node --version                           # v24.x
free -h                                  # confirm swap is allocated
```

## Maintaining existing servers

Only new 26.04 servers are provisioned from scratch. Existing 22.04 and 24.04 servers are maintained in place with two commands.

**`bin/dotfiles`** pulls this repo and re-runs `setup.sh`, which works on any Ubuntu release. Each run applies package upgrades, moves Node.js to `NODE_MAJOR` when it changes, and runs `composer self-update`. Upgrades include patch releases for PHP, MySQL, Nginx, Redis, Supervisor, and Node.js, and a service restarts when its package is upgraded.

Unattended upgrades only apply security updates from Ubuntu's own archive. PHP (packages.sury.org or the ondrej/php PPA) and Node.js (NodeSource) come from third-party repositories, so their security patches arrive only when you run `bin/dotfiles`. Run it regularly, and promptly after a PHP security release.

**`~/.dotfiles/provision/software/php.sh <version>`** adds a newer PHP to a server on 22.04, 24.04, or 26.04. It uses the ondrej/php PPA on 22.04 and 24.04 and packages.sury.org on 26.04, installs the standard extension set, and starts the new FPM alongside the current one. It applies no tuning; that is the optional `tune_php` step below. The new pool copies the current pool's `user`, `group`, `listen.owner`, `listen.group`, and `env[HOME]`. The `php` CLI stays on the current version, and nothing is switched over: the script prints the cutover steps (Nginx socket, `update-alternatives`, deploy reload and sudoers, queue workers, disabling the old FPM). Until the Nginx socket changes, the old version keeps serving, so the install is safe to run on a live server. From PHP 8.5 the script skips the `opcache` package, since OPcache is compiled into core.

**`tune_php <version> [version ...]`** writes the OPcache and realpath_cache tuning described above to each named version's FPM and CLI `99-tuning.ini`, and restarts that version's FPM only if the file changed. The Laravel provision script runs it on new servers. On an existing server it is optional after installing a new PHP, and you can run it any time after changing a tuning value. It never guesses which versions to tune: `opcache.validate_timestamps=0` assumes a deploy pipeline that reloads PHP-FPM, so only name versions that deploy that way.

Ondřej has announced that 22.04 and 24.04 users will be moved from the Launchpad PPA to packages.sury.org. When that happens, `software/php.sh` needs to follow.

**MySQL on older servers.** Check `mysql --version`. A server still on Ubuntu's MySQL 8.0 is past end of life (April 21, 2026). Moving to 8.4 LTS from [Oracle's APT repository](https://dev.mysql.com/downloads/repo/apt/) is an in-place upgrade that can't be rolled back, so take a full backup first.

**Ubuntu 22.04 reaches end of standard support in April 2027.** Reaching 26.04 in place takes two release upgrades, so replacing a 22.04 server with a freshly provisioned 26.04 droplet is usually less work.

## Resources

- DigitalOcean: [Initial Server Setup with Ubuntu 24.04](https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-24-04)
- DigitalOcean: [How To Install Linux, Nginx, MySQL, PHP (LEMP) on Ubuntu 24.04](https://www.digitalocean.com/community/tutorials/how-to-install-linux-nginx-mysql-php-lemp-stack-on-ubuntu-24-04)
- Ondřej Surý PHP PPA (22.04/24.04, used by `software/php.sh`): [launchpad.net/~ondrej/+archive/ubuntu/php](https://launchpad.net/~ondrej/+archive/ubuntu/php)
- Ondřej Surý PHP repo (26.04): [packages.sury.org/php](https://packages.sury.org/php/)
- Oracle MySQL APT repo (upgrading older servers): [dev.mysql.com/downloads/repo/apt](https://dev.mysql.com/downloads/repo/apt/)
