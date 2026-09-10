#!/usr/bin/env bash
#
# provision-laravel-app-server.sh
#
# Provision an Ubuntu 24.04 LTS server for Laravel hosting:
#   Nginx, PHP 8.4-FPM, MySQL 8.4 LTS, Redis, Supervisor, Composer, Node.js 24.
#
# Run AFTER setup.sh has been run (gates on ~/setup-complete.log).
#
# Run as the administrative user (NOT root), after:
#   1. Creating the user and adding to the sudo group
#   2. Copying your SSH public key to the server
#   3. Hardening sshd_config (see the companion how-to doc)
#   4. Running provision/setup.sh (or bin/dotfiles)
#
# Optional environment variables:
#   PHP_VERSION              defaults to 8.4
#   NODE_MAJOR               defaults to 24
#   MYSQL_APT_CONFIG_VERSION defaults to 0.8.34-1
#   MYSQL_ROOT_PASSWORD      auto-generated if unset
#

set -euo pipefail

source "${HOME}/.dotfiles/lib/config.sh"

# --- Configuration -----------------------------------------------------------

PHP_VERSION="${PHP_VERSION:-8.4}"
NODE_MAJOR="${NODE_MAJOR:-24}"
MYSQL_APT_CONFIG_VERSION="${MYSQL_APT_CONFIG_VERSION:-0.8.34-1}"

LOG_FILE="$HOME/provision.log"
MYSQL_PASS_FILE="$HOME/.mysql_root_password"

exec > >(tee -a "$LOG_FILE") 2>&1

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

if [[ ! -f "${HOME}/setup-complete.log" ]]; then
  echo "setup.sh has not been run successfully. Run provision/setup.sh first." >&2
  exit 1
fi

ok "Running as $(whoami) on $(lsb_release -ds)"

export DEBIAN_FRONTEND=noninteractive

# --- System update -----------------------------------------------------------

section "System update"
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
ok "System packages up to date"

# --- Nginx -------------------------------------------------------------------

section "Nginx"
sudo apt-get install -y -qq nginx
sudo ufw allow 'Nginx Full'
sudo systemctl enable --now nginx >/dev/null

if [[ ! -f /etc/nginx/sites-available/00-catch-all ]]; then
  sudo tee /etc/nginx/sites-available/00-catch-all >/dev/null <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    ssl_reject_handshake on;
    server_name _;
    return 444;
}
NGINX
  sudo ln -sf /etc/nginx/sites-available/00-catch-all /etc/nginx/sites-enabled/00-catch-all
fi

if [[ -L /etc/nginx/sites-enabled/default ]]; then
  sudo rm /etc/nginx/sites-enabled/default
fi

sudo nginx -t && sudo systemctl reload nginx
ok "Nginx running with catch-all default server"

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
  if [[ -z "${MYSQL_ROOT_PASSWORD:-}" ]]; then
    MYSQL_ROOT_PASSWORD="$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-28)"
  fi

  umask 077
  printf '%s\n' "$MYSQL_ROOT_PASSWORD" > "$MYSQL_PASS_FILE"
  ok "MySQL root password written to $MYSQL_PASS_FILE"

  MYSQL_APT_DEB="mysql-apt-config_${MYSQL_APT_CONFIG_VERSION}_all.deb"
  curl -fsSL "https://repo.mysql.com/${MYSQL_APT_DEB}" -o "/tmp/${MYSQL_APT_DEB}"

  echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.4-lts" | sudo debconf-set-selections
  echo "mysql-apt-config mysql-apt-config/select-tools select Enabled" | sudo debconf-set-selections
  echo "mysql-apt-config mysql-apt-config/select-product select Ok" | sudo debconf-set-selections
  sudo -E dpkg -i "/tmp/${MYSQL_APT_DEB}"
  rm -f "/tmp/${MYSQL_APT_DEB}"

  sudo apt-get update -qq

  echo "mysql-community-server mysql-community-server/root-pass password ${MYSQL_ROOT_PASSWORD}" | sudo debconf-set-selections
  echo "mysql-community-server mysql-community-server/re-root-pass password ${MYSQL_ROOT_PASSWORD}" | sudo debconf-set-selections
  echo "mysql-server mysql-server/default-auth-override select Use Strong Password Encryption (RECOMMENDED)" | sudo debconf-set-selections

  sudo -E apt-get install -y -qq mysql-server
  sudo systemctl enable --now mysql >/dev/null
  ok "MySQL $(mysql --version | awk '{print $3}') running"
fi

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
