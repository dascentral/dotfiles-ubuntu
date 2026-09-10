#!/usr/bin/env bash
set -euo pipefail

section "Composer"
if command -v composer >/dev/null 2>&1; then
  ok "Composer already installed: $(composer --version --no-ansi 2>/dev/null | head -n1)"
else
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
  ok "Composer $(composer --version --no-ansi 2>/dev/null | head -n1)"
fi
