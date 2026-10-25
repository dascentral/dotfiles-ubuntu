#!/usr/bin/env bash
set -euo pipefail

SWAP_SIZE_GB="${SWAP_SIZE_GB:-2}"

section "System defaults"

sudo timedatectl set-timezone UTC
ok "Timezone set to UTC"

if write_if_changed /etc/systemd/journald.conf.d/99-cap.conf <<'EOF'
[Journal]
SystemMaxUse=500M
SystemKeepFree=1G
EOF
then
  sudo systemctl restart systemd-journald
fi
ok "journald capped at 500MB"

section "Swap file (${SWAP_SIZE_GB}GB)"
if swapon --show | grep -q '/swapfile'; then
  ok "Swap file already configured"
else
  sudo fallocate -l "${SWAP_SIZE_GB}G" /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile >/dev/null
  sudo swapon /swapfile
  if ! grep -q '/swapfile' /etc/fstab; then
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
  fi
  echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf >/dev/null
  sudo sysctl --quiet -p /etc/sysctl.d/99-swappiness.conf
  ok "Swap file created and enabled"
fi
