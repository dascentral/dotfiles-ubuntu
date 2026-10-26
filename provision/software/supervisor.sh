#!/usr/bin/env bash
set -euo pipefail

section "Supervisor"
sudo apt-get install -y -qq --no-upgrade supervisor
sudo systemctl enable --now supervisor >/dev/null
ok "Supervisor running"
