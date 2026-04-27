#!/usr/bin/env bash
#
# provision.sh
#
# Provision a fresh Ubuntu 24.04 LTS droplet for Laravel hosting:
#   Nginx, PHP 8.4-FPM, MySQL 8.4 LTS, Redis, Supervisor, Composer, Node.js 24.
#
# Run as the administrative user (NOT root), after:
#   1. Creating the user and adding to the sudo group
#   2. Copying your SSH public key to the server
#   3. Hardening sshd_config (see the companion how-to doc)
#
# Optional environment variables:
#   PHP_VERSION              defaults to 8.4
#   NODE_MAJOR               defaults to 24
#   SWAP_SIZE_GB             defaults to 2
#   MYSQL_APT_CONFIG_VERSION defaults to 0.8.34-1
#   MYSQL_ROOT_PASSWORD      auto-generated if unset
#

set -euo pipefail

# --- Configuration -----------------------------------------------------------

PHP_VERSION="${PHP_VERSION:-8.4}"
NODE_MAJOR="${NODE_MAJOR:-24}"
SWAP_SIZE_GB="${SWAP_SIZE_GB:-2}"
MYSQL_APT_CONFIG_VERSION="${MYSQL_APT_CONFIG_VERSION:-0.8.34-1}"

LOG_FILE="$HOME/provision.log"
MYSQL_PASS_FILE="$HOME/.mysql_root_password"

# Mirror everything to a log file.
exec > >(tee -a "$LOG_FILE") 2>&1

section() {
  printf '\n\033[1;34m==> %s\033[0m\n' "$1"
}

ok() {
  printf '\033[1;32m    ok:\033[0m %s\n' "$1"
}

# --- Pre-flight checks -------------------------------------------------------

section "Pre-flight checks"

if [[ $EUID -eq 0 ]]; then
  echo "Run this script as your administrative user (with sudo), not as root." >&2
  exit 1
fi

if ! sudo -n true 2>/dev/null; then
  echo "This script needs sudo. You may be prompted for your password."
  sudo -v
fi

if ! grep -q 'Ubuntu 24.04' /etc/os-release; then
  echo "This script targets Ubuntu 24.04 LTS. Detected:" >&2
  grep PRETTY_NAME /etc/os-release >&2
  exit 1
fi

ok "Running as $(whoami) on $(lsb_release -ds)"

export DEBIAN_FRONTEND=noninteractive

# --- System update -----------------------------------------------------------

section "System update"
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
ok "System packages up to date"

# --- Base utilities ----------------------------------------------------------

section "Base utilities"
sudo apt-get install -y -qq \
  ca-certificates apt-transport-https software-properties-common gnupg lsb-release \
  git tmux vim curl wget zip unzip htop jq rsync
ok "Base utilities installed"

# --- System defaults ---------------------------------------------------------

section "System defaults"

# Pin the server clock to UTC. Laravel handles timezone presentation in PHP;
# the OS staying in UTC keeps cron, systemd, MySQL, and application logs all
# speaking the same dialect.
sudo timedatectl set-timezone UTC
ok "Timezone set to UTC"

# Cap journald disk usage. Default is 10% of the filesystem, which on a
# multi-year-old droplet quietly grows into multiple GB.
sudo mkdir -p /etc/systemd/journald.conf.d
sudo tee /etc/systemd/journald.conf.d/99-cap.conf >/dev/null <<'EOF'
[Journal]
SystemMaxUse=500M
SystemKeepFree=1G
EOF
sudo systemctl restart systemd-journald
ok "journald capped at 500MB"

# --- UFW ---------------------------------------------------------------------

section "UFW firewall"
sudo apt-get install -y -qq ufw
sudo ufw --force default deny incoming
sudo ufw --force default allow outgoing
sudo ufw allow OpenSSH
if ! sudo ufw status | grep -q "Status: active"; then
  sudo ufw --force enable
fi
ok "UFW active, OpenSSH allowed"

# --- Fail2Ban ----------------------------------------------------------------

section "Fail2Ban"
sudo apt-get install -y -qq fail2ban
sudo systemctl enable --now fail2ban >/dev/null
ok "Fail2Ban running"

# --- Unattended security upgrades --------------------------------------------

section "Unattended security upgrades"
sudo apt-get install -y -qq unattended-upgrades apt-listchanges
echo 'unattended-upgrades unattended-upgrades/enable_auto_updates boolean true' | sudo debconf-set-selections
sudo dpkg-reconfigure -f noninteractive unattended-upgrades
ok "Security upgrades will be applied automatically"

# --- Swap file ---------------------------------------------------------------

section "Swap file (${SWAP_SIZE_GB}GB)"
if swapon --show | grep -q '/swapfile'; then
  ok "Swap file already configured"
else
  sudo fallocate -l "${SWAP_SIZE_GB}G" /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile >/dev/null
  sudo swapon /swapfile
  if ! grep -q '/swapfile' /etc/fstab; then
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
  fi
  echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf >/dev/null
  sudo sysctl --quiet -p /etc/sysctl.d/99-swappiness.conf
  ok "Swap file created and enabled"
fi

# --- Nginx -------------------------------------------------------------------

section "Nginx"
sudo apt-get install -y -qq nginx
sudo ufw allow 'Nginx Full'
sudo systemctl enable --now nginx >/dev/null
ok "Nginx running"

# --- Redis -------------------------------------------------------------------

section "Redis"
sudo apt-get install -y -qq redis-server
sudo systemctl enable --now redis-server >/dev/null
ok "Redis running"

# --- Supervisor --------------------------------------------------------------

section "Supervisor"
sudo apt-get install -y -qq supervisor
sudo systemctl enable --now supervisor >/dev/null
ok "Supervisor running"

# --- PHP ${PHP_VERSION} ------------------------------------------------------

section "PHP ${PHP_VERSION} (via ondrej/php PPA)"
if ! grep -rq 'ondrej/php' /etc/apt/sources.list.d/ 2>/dev/null; then
  sudo add-apt-repository -y ppa:ondrej/php
  sudo apt-get update -qq
fi
sudo apt-get install -y -qq \
  "php${PHP_VERSION}" \
  "php${PHP_VERSION}-fpm" \
  "php${PHP_VERSION}-cli" \
  "php${PHP_VERSION}-common" \
  "php${PHP_VERSION}-bcmath" \
  "php${PHP_VERSION}-curl" \
  "php${PHP_VERSION}-gd" \
  "php${PHP_VERSION}-intl" \
  "php${PHP_VERSION}-ldap" \
  "php${PHP_VERSION}-mbstring" \
  "php${PHP_VERSION}-mysql" \
  "php${PHP_VERSION}-opcache" \
  "php${PHP_VERSION}-readline" \
  "php${PHP_VERSION}-redis" \
  "php${PHP_VERSION}-xml" \
  "php${PHP_VERSION}-zip"
sudo systemctl enable --now "php${PHP_VERSION}-fpm" >/dev/null
ok "PHP ${PHP_VERSION} and FPM running"

# Production-leaning OPcache and realpath_cache tuning. Defaults are sized for
# small apps; Laravel's vendor tree alone routinely exceeds the default
# 10,000-file cap once you've got more than a couple of apps on the box.
# validate_timestamps=0 means OPcache never re-stats files to check for
# changes; deploys MUST reload PHP-FPM to pick up new code.
# Goes into both the FPM and CLI ini directories so artisan commands benefit.
section "PHP tuning (OPcache, realpath_cache)"
TUNING_INI=$(cat <<'EOF'
; Provisioned tuning
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.validate_timestamps=0
realpath_cache_size=4096K
realpath_cache_ttl=600
EOF
)
for sapi in fpm cli; do
  echo "$TUNING_INI" | sudo tee "/etc/php/${PHP_VERSION}/${sapi}/conf.d/99-tuning.ini" >/dev/null
done
sudo systemctl restart "php${PHP_VERSION}-fpm"
ok "OPcache: 256MB / 20k files / no timestamp validation; realpath_cache: 4MB / 600s"

# --- MySQL 8.4 LTS (Oracle official APT repo) --------------------------------

section "MySQL 8.4 LTS"
if command -v mysql >/dev/null 2>&1; then
  ok "MySQL already installed: $(mysql --version)"
else
  # Generate a strong root password if one wasn't supplied.
  if [[ -z "${MYSQL_ROOT_PASSWORD:-}" ]]; then
    MYSQL_ROOT_PASSWORD="$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-28)"
  fi

  # Save it for the operator before doing anything else.
  umask 077
  printf '%s\n' "$MYSQL_ROOT_PASSWORD" > "$MYSQL_PASS_FILE"
  ok "MySQL root password written to $MYSQL_PASS_FILE"

  # Add Oracle's MySQL APT repo configuration package, non-interactively.
  MYSQL_APT_DEB="mysql-apt-config_${MYSQL_APT_CONFIG_VERSION}_all.deb"
  curl -fsSL "https://repo.mysql.com/${MYSQL_APT_DEB}" -o "/tmp/${MYSQL_APT_DEB}"

  echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.4-lts" | sudo debconf-set-selections
  echo "mysql-apt-config mysql-apt-config/select-tools select Enabled" | sudo debconf-set-selections
  echo "mysql-apt-config mysql-apt-config/select-product select Ok" | sudo debconf-set-selections
  sudo -E dpkg -i "/tmp/${MYSQL_APT_DEB}"
  rm -f "/tmp/${MYSQL_APT_DEB}"

  sudo apt-get update -qq

  # Pre-seed the server install: root password and modern auth plugin.
  echo "mysql-community-server mysql-community-server/root-pass password ${MYSQL_ROOT_PASSWORD}" | sudo debconf-set-selections
  echo "mysql-community-server mysql-community-server/re-root-pass password ${MYSQL_ROOT_PASSWORD}" | sudo debconf-set-selections
  echo "mysql-server mysql-server/default-auth-override select Use Strong Password Encryption (RECOMMENDED)" | sudo debconf-set-selections

  sudo -E apt-get install -y -qq mysql-server
  sudo systemctl enable --now mysql >/dev/null
  ok "MySQL $(mysql --version | awk '{print $3}') running"
fi

# Size innodb_buffer_pool_size to detected RAM. The MySQL 8 default of 128MB
# is fine for "hello world" and painful for anything that joins. Convention
# is ~50% of total RAM on a dedicated DB host; on a shared application server
# we leave more headroom for FPM, Redis, and Horizon.
section "MySQL tuning"
TOTAL_MEM_MB=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
if   (( TOTAL_MEM_MB >= 7168 )); then BUFFER_POOL_MB=$((TOTAL_MEM_MB * 40 / 100))
elif (( TOTAL_MEM_MB >= 3584 )); then BUFFER_POOL_MB=$((TOTAL_MEM_MB * 35 / 100))
elif (( TOTAL_MEM_MB >= 1792 )); then BUFFER_POOL_MB=512
else                                   BUFFER_POOL_MB=256
fi
sudo tee /etc/mysql/conf.d/99-tuning.cnf >/dev/null <<EOF
# Provisioned tuning. Detected ${TOTAL_MEM_MB}MB total RAM.
[mysqld]
innodb_buffer_pool_size = ${BUFFER_POOL_MB}M
EOF
sudo systemctl restart mysql
ok "innodb_buffer_pool_size set to ${BUFFER_POOL_MB}M (host has ${TOTAL_MEM_MB}MB RAM)"

# --- Composer ----------------------------------------------------------------

section "Composer"
if command -v composer >/dev/null 2>&1; then
  ok "Composer already installed: $(composer --version --no-ansi 2>/dev/null | head -n1)"
else
  EXPECTED_CHECKSUM="$(curl -fsSL https://composer.github.io/installer.sig)"
  php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
  ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")"
  if [[ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]]; then
    echo "Composer installer checksum mismatch. Aborting." >&2
    rm -f /tmp/composer-setup.php
    exit 1
  fi
  sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer --quiet
  rm -f /tmp/composer-setup.php
  ok "Composer $(composer --version --no-ansi 2>/dev/null | head -n1)"
fi

# --- Node.js (NodeSource) ----------------------------------------------------

section "Node.js ${NODE_MAJOR}.x LTS"
if command -v node >/dev/null 2>&1 && node --version | grep -q "^v${NODE_MAJOR}\."; then
  ok "Node.js already installed: $(node --version)"
else
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash - >/dev/null
  sudo apt-get install -y -qq nodejs
  ok "Node.js $(node --version), npm $(npm --version)"
fi

# --- Done --------------------------------------------------------------------

section "Provisioning complete"
cat <<EOF

Next steps (manual):

  1. Read your MySQL root password and store it somewhere safe:
       cat ${MYSQL_PASS_FILE}

  2. Run the MySQL hardening script:
       sudo mysql_secure_installation

  3. Edit /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf to set the FPM
     pool to run as your admin user instead of www-data, then:
       sudo systemctl restart php${PHP_VERSION}-fpm

  4. Drop in your per-app Nginx server blocks, Supervisor configs,
     and logrotate configs from each application repo.

  5. Once DNS is pointing at this droplet:
       sudo apt install -y certbot python3-certbot-nginx
       sudo certbot --nginx -d example.com

Provisioning log: ${LOG_FILE}

EOF
