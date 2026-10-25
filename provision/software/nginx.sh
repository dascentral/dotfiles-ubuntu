#!/usr/bin/env bash
set -euo pipefail

section "Nginx"
sudo apt-get install -y -qq --no-upgrade nginx
sudo ufw allow 'Nginx Full' >/dev/null
sudo systemctl enable --now nginx >/dev/null

NGINX_CHANGED=false
if write_if_changed /etc/nginx/sites-available/00-catch-all <<'NGINX'
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
then
  NGINX_CHANGED=true
fi

if [[ ! -L /etc/nginx/sites-enabled/00-catch-all ]]; then
  sudo ln -sf /etc/nginx/sites-available/00-catch-all /etc/nginx/sites-enabled/00-catch-all
  NGINX_CHANGED=true
fi

if [[ -L /etc/nginx/sites-enabled/default ]]; then
  sudo rm /etc/nginx/sites-enabled/default
  NGINX_CHANGED=true
fi

if [[ "$NGINX_CHANGED" == true ]]; then
  sudo nginx -t
  sudo systemctl reload nginx
  ok "Nginx running; catch-all default server updated and reloaded"
else
  ok "Nginx running; catch-all default server unchanged"
fi
