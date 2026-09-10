#!/usr/bin/env bash
set -euo pipefail

section "Redis"
sudo apt-get install -y -qq redis-server
sudo systemctl enable --now redis-server >/dev/null
ok "Redis running"
