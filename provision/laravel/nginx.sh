#!/usr/bin/env bash
set -euo pipefail

section "Nginx"
sudo apt-get install -y -qq nginx
sudo ufw allow 'Nginx Full'
sudo systemctl enable --now nginx >/dev/null

if [[ ! -f /etc/nginx/sites-available/00-catch-all ]]; then
  sudo tee /etc/nginx/sites-available/00-catch-all >/dev/null <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    ssl_reject_handshake on;
    server_name _;
    return 444;
}
NGINX
  sudo ln -sf /etc/nginx/sites-available/00-catch-all /etc/nginx/sites-enabled/00-catch-all
fi

if [[ -L /etc/nginx/sites-enabled/default ]]; then
  sudo rm /etc/nginx/sites-enabled/default
fi

sudo nginx -t && sudo systemctl reload nginx
ok "Nginx running with catch-all default server"
