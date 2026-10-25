#!/usr/bin/env bash
#
# provision-laravel-app-server.sh
#
# Provision an Ubuntu 26.04 LTS server for Laravel hosting:
# - Nginx
# - PHP 8.4-FPM (via bin/install_php)
# - MySQL 8.4 LTS
# - Redis
# - Supervisor
# - Composer
#
# Run AFTER setup.sh has been run (gates on $LOG_SETUP_COMPLETE).
#
# Run as the administrative user (NOT root), after:
# 1. Creating the user and adding to the sudo group
# 2. Copying your SSH public key to the server
# 3. Hardening sshd_config (see the companion how-to doc)
# 4. Running provision/setup.sh (or bin/dotfiles)
#
# Optional environment variables:
#   PHP_VERSION              defaults to 8.4
#   MYSQL_ROOT_PASSWORD      auto-generated if unset
#

set -euo pipefail

source "${HOME}/.dotfiles/lib/config.sh"

# --- Configuration -----------------------------------------------------------

PHP_VERSION="${PHP_VERSION:-8.4}"

LARAVEL_DIR="${DOTFILES}/provision/laravel"
LOG_FILE="$LOG_PROVISION_LARAVEL"
MYSQL_PASS_FILE="$HOME/.mysql_root_password"

mkdir -p "$LOG_DIR"
exec > >(tee "$LOG_FILE") 2>&1

# --- Pre-flight checks -------------------------------------------------------

section "Pre-flight checks"

if [[ $EUID -eq 0 ]]; then
  die "Run this script as your administrative user (with sudo), not as root."
fi

if ! sudo -n true 2>/dev/null; then
  info "This script needs sudo. You may be prompted for your password."
  sudo -v
fi

require_ubuntu 26.04

if [[ ! -f "$LOG_SETUP_COMPLETE" ]]; then
  die "setup.sh has not been run successfully. Run provision/setup.sh first."
fi

ok "Running as $(whoami) on $(lsb_release -ds)"

export DEBIAN_FRONTEND=noninteractive

# --- System update -----------------------------------------------------------

section "System update"
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
ok "System packages up to date"

# --- Run modules --------------------------------------------------------------

source "${LARAVEL_DIR}/nginx.sh"
source "${LARAVEL_DIR}/redis.sh"
source "${LARAVEL_DIR}/supervisor.sh"
"${DOTFILES}/bin/install_php" "$PHP_VERSION"
source "${LARAVEL_DIR}/mysql.sh"
source "${LARAVEL_DIR}/composer.sh"

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
