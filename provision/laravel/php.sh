#!/usr/bin/env bash
set -euo pipefail

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
