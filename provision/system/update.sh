#!/usr/bin/env bash
set -euo pipefail

section "System update"
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
sudo apt-get autoremove -y -qq
ok "System packages up to date"
