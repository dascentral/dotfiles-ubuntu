#!/usr/bin/env bash
set -euo pipefail

section "Base utilities"
sudo apt-get install -y -qq \
  ca-certificates apt-transport-https software-properties-common gnupg lsb-release \
  git tmux vim curl wget zip unzip htop jq rsync ncdu silversearcher-ag
ok "Base utilities installed"
