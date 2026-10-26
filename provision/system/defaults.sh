#!/usr/bin/env bash
set -euo pipefail

SWAP_SIZE_GB="${SWAP_SIZE_GB:-2}"

section "System defaults"

# Timezone
sudo timedatectl set-timezone UTC
ok "Timezone set to UTC"

# Journal size
if write_if_changed /etc/systemd/journald.conf.d/99-cap.conf <<'EOF'
[Journal]
SystemMaxUse=500M
SystemKeepFree=1G
EOF
then
  sudo systemctl restart systemd-journald
fi
ok "journald capped at 500MB"

# Swap file
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
  ok "Swap file created and enabled"
fi

if write_if_changed /etc/sysctl.d/99-swappiness.conf <<'EOF'
vm.swappiness=10
EOF
then
  sudo sysctl --quiet -p /etc/sysctl.d/99-swappiness.conf
fi
ok "vm.swappiness set to 10"
