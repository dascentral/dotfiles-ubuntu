#!/usr/bin/env bash
set -euo pipefail

NODE_MAJOR="${NODE_MAJOR:-24}"

section "Node.js ${NODE_MAJOR}.x LTS"
if command -v node >/dev/null 2>&1 && node --version | grep -q "^v${NODE_MAJOR}\."; then
  ok "Node.js already installed: $(node --version)"
else
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash - >/dev/null
  sudo apt-get install -y -qq nodejs
  ok "Node.js $(node --version), npm $(npm --version)"
fi
