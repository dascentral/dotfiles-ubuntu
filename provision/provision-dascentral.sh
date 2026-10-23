#!/usr/bin/env bash
#
# provision-dascentral.sh
#
# Provision dascentral.com application dependencies on Ubuntu 22.04, 24.04, or 26.04 LTS:
# - Headless Chromium (via Puppeteer)
# - qpdf
# - Ghostscript
# - LibreOffice
#
# Run AFTER provision-laravel-app-server.sh (requires PHP-FPM).
#
# Optional environment variables:
#   APP_USER     defaults to forge
#   PHP_VERSION  defaults to 8.4
#

set -euo pipefail

source "${HOME}/.dotfiles/lib/config.sh"

# --- Configuration -----------------------------------------------------------

APP_USER="${APP_USER:-forge}"
PHP_VERSION="${PHP_VERSION:-8.4}"

LOG_FILE="$LOG_PROVISION_DASCENTRAL"
APP_USER_HOME="/home/${APP_USER}"
FPM_POOL="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"

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

require_ubuntu 22.04 24.04 26.04

if [[ ! -f "$LOG_PROVISION_LARAVEL" ]]; then
  die "provision-laravel-app-server.sh has not been run. Run it first."
fi

if ! id "$APP_USER" >/dev/null 2>&1; then
  die "User '${APP_USER}' does not exist."
fi

ok "Running as $(whoami) on $(lsb_release -ds)"

export DEBIAN_FRONTEND=noninteractive

# --- System update -----------------------------------------------------------

section "System update"
sudo apt-get update -qq
ok "Package index refreshed"

# --- Headless Chromium system dependencies -----------------------------------

section "Headless Chromium system dependencies"
# 24.04's 64-bit time_t transition renamed libasound2. The other renamed libs
# keep their old names as virtual packages, but libasound2 has multiple providers.
if ubuntu_version_lt 24.04; then LIBASOUND=libasound2; else LIBASOUND=libasound2t64; fi
sudo apt-get install -y -qq \
  ca-certificates \
  fonts-liberation \
  "$LIBASOUND" \
  libatk-bridge2.0-0 \
  libatk1.0-0 \
  libcairo2 \
  libcups2 \
  libdbus-1-3 \
  libdrm2 \
  libgbm1 \
  libglib2.0-0 \
  libgtk-3-0 \
  libnspr4 \
  libnss3 \
  libpango-1.0-0 \
  libx11-6 \
  libxcb1 \
  libxcomposite1 \
  libxdamage1 \
  libxext6 \
  libxfixes3 \
  libxkbcommon0 \
  libxrandr2 \
  xdg-utils
ok "Chromium system libraries installed"

# --- Puppeteer Chrome browser ------------------------------------------------

section "Puppeteer Chrome browser"
sudo -u "$APP_USER" -H /usr/bin/npx --yes puppeteer browsers install chrome
ok "Chrome browser up to date at ${APP_USER_HOME}/.cache/puppeteer/"

# --- qpdf --------------------------------------------------------------------

section "qpdf"
sudo apt-get install -y -qq qpdf
ok "qpdf $(qpdf --version 2>&1 | head -n1)"

# --- Ghostscript -------------------------------------------------------------

section "Ghostscript"
sudo apt-get install -y -qq ghostscript
ok "Ghostscript $(/usr/bin/gs --version)"

# --- LibreOffice -------------------------------------------------------------

section "LibreOffice"
sudo apt-get install -y -qq --no-install-recommends libreoffice
ok "LibreOffice $(/usr/bin/soffice --version 2>&1 | head -n1)"

section "LibreOffice configuration for ${APP_USER}"
sudo -u "$APP_USER" mkdir -p "${APP_USER_HOME}/.config/libreoffice"
ok "LibreOffice config directory exists"

if [[ -f "$FPM_POOL" ]]; then
  if grep -qE '^\s*env\[HOME\]\s*=' "$FPM_POOL"; then
    ok "env[HOME] already set in ${FPM_POOL}"
  else
    printf '\nenv[HOME] = %s\n' "$APP_USER_HOME" | sudo tee -a "$FPM_POOL" >/dev/null
    sudo systemctl reload "php${PHP_VERSION}-fpm"
    ok "Added env[HOME] = ${APP_USER_HOME} and reloaded PHP-FPM"
  fi
else
  warn "FPM pool not found at ${FPM_POOL} — add env[HOME] = ${APP_USER_HOME} manually"
fi

# --- Done --------------------------------------------------------------------

section "dascentral.com provisioning complete"
cat <<EOF

Provisioning log: ${LOG_FILE}

EOF
