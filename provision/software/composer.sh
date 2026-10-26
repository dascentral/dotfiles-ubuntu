#!/usr/bin/env bash
set -euo pipefail

# Sourced by setup.sh (every server) and provision-laravel-app-server.sh.
# On a new server setup.sh runs before PHP exists, so the install happens
# in the Laravel script and later bin/dotfiles runs keep Composer current.

section "Composer"
if command -v composer >/dev/null 2>&1; then
  sudo env COMPOSER_ALLOW_SUPERUSER=1 composer self-update --no-interaction --quiet
  ok "$(composer --version --no-ansi 2>/dev/null | head -n1)"
elif command -v php >/dev/null 2>&1; then
  EXPECTED_CHECKSUM="$(curl -fsSL https://composer.github.io/installer.sig)"
  php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
  ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")"
  if [[ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]]; then
    warn "Composer installer checksum mismatch. Aborting."
    rm -f /tmp/composer-setup.php
    exit 1
  fi
  sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer --quiet
  rm -f /tmp/composer-setup.php
  ok "Installed $(composer --version --no-ansi 2>/dev/null | head -n1)"
else
  ok "PHP not installed; skipping Composer"
fi
