#!/usr/bin/env bash
set -euo pipefail

if ubuntu_version_lt 26.04; then
  section "PHP ${PHP_VERSION} (via ondrej/php PPA)"
  if ! grep -rq 'ondrej/php' /etc/apt/sources.list.d/ 2>/dev/null; then
    sudo add-apt-repository -y ppa:ondrej/php
    sudo apt-get update -qq
  fi
else
  # The Launchpad PPA does not publish for 26.04; packages.sury.org is the
  # same maintainer's canonical repo there.
  section "PHP ${PHP_VERSION} (via packages.sury.org)"
  if ! grep -rq 'packages.sury.org/php' /etc/apt/sources.list.d/ 2>/dev/null; then
    curl -fsSL https://packages.sury.org/debsuryorg-archive-keyring.deb -o /tmp/debsuryorg-archive-keyring.deb
    sudo dpkg -i /tmp/debsuryorg-archive-keyring.deb >/dev/null
    rm -f /tmp/debsuryorg-archive-keyring.deb
    echo "deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" \
      | sudo tee /etc/apt/sources.list.d/php.list >/dev/null
    sudo apt-get update -qq
  fi
fi

if ! apt-cache show "php${PHP_VERSION}-fpm" >/dev/null 2>&1; then
  die "php${PHP_VERSION}-fpm is not available on Ubuntu $(ubuntu_version)."
fi

PHP_EXTENSIONS=(fpm cli common bcmath curl gd intl ldap mbstring mysql readline redis xml zip)
# OPcache is compiled into core from PHP 8.5 and no longer ships as a package.
if dpkg --compare-versions "$PHP_VERSION" lt 8.5; then
  PHP_EXTENSIONS+=(opcache)
fi
sudo apt-get install -y -qq "php${PHP_VERSION}" "${PHP_EXTENSIONS[@]/#/php${PHP_VERSION}-}"
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
