#!/usr/bin/env bash
set -euo pipefail

section "Nginx"
sudo apt-get install -y -qq nginx
sudo ufw allow 'Nginx Full'
sudo systemctl enable --now nginx >/dev/null

if ubuntu_version_lt 24.04; then
  # 22.04 ships Nginx 1.18, which predates ssl_reject_handshake (1.19.4) and
  # refuses an ssl listener without a certificate. Present the snakeoil cert
  # instead; unknown SNI completes the handshake and then gets the 444.
  sudo apt-get install -y -qq ssl-cert
  TLS_REJECT="    ssl_certificate     /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;"
else
  TLS_REJECT="    ssl_reject_handshake on;"
fi

if [[ ! -f /etc/nginx/sites-available/00-catch-all ]]; then
  sudo tee /etc/nginx/sites-available/00-catch-all >/dev/null <<NGINX
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
${TLS_REJECT}
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
