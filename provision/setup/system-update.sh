#!/usr/bin/env bash
set -euo pipefail

section "System update"

if ubuntu_version_lt 24.04; then
  # needrestart on 22.04 opens an interactive restart dialog during apt runs,
  # which hangs unattended provisioning. Match the 24.04+ default of restarting
  # services automatically and print kernel hints instead of prompting.
  sudo mkdir -p /etc/needrestart/conf.d
  sudo tee /etc/needrestart/conf.d/99-noninteractive.conf >/dev/null <<'EOF'
$nrconf{restart} = 'a';
$nrconf{kernelhints} = -1;
EOF
  ok "needrestart set to restart services without prompting"
fi

sudo apt-get update -qq
sudo apt-get upgrade -y -qq
sudo apt-get autoremove -y -qq
ok "System packages up to date"
