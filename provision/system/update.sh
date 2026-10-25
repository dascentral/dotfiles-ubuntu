#!/usr/bin/env bash
set -euo pipefail

section "System update"
sudo apt-get update -qq
# --with-new-pkgs lets upgrades that need a new dependency (e.g. a sury.org
# PHP build moving to a newer libicu) go through instead of being kept back.
sudo apt-get upgrade -y -qq --with-new-pkgs
sudo apt-get autoremove -y -qq
ok "System packages up to date"
