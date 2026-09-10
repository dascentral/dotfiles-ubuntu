#!/usr/bin/env bash
set -euo pipefail

section "UFW firewall"
sudo apt-get install -y -qq ufw
sudo ufw --force default deny incoming
sudo ufw --force default allow outgoing
sudo ufw allow OpenSSH
if ! sudo ufw status | grep -q "Status: active"; then
  sudo ufw --force enable
fi
ok "UFW active, OpenSSH allowed"

section "Fail2Ban"
sudo apt-get install -y -qq fail2ban
sudo systemctl enable --now fail2ban >/dev/null 2>&1
ok "Fail2Ban running"

section "Unattended security upgrades"
sudo apt-get install -y -qq unattended-upgrades apt-listchanges
echo 'unattended-upgrades unattended-upgrades/enable_auto_updates boolean true' | sudo debconf-set-selections
sudo dpkg-reconfigure -f noninteractive unattended-upgrades
ok "Security upgrades will be applied automatically"
