#!/usr/bin/env bash
set -euo pipefail

section "Composer"
if command -v composer >/dev/null 2>&1; then
  sudo env COMPOSER_ALLOW_SUPERUSER=1 composer self-update --no-interaction --quiet
  ok "$(composer --version --no-ansi 2>/dev/null | head -n1)"
else
  ok "Composer not installed; skipping self-update"
fi
