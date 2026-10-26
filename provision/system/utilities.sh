#!/usr/bin/env bash
set -euo pipefail

section "Base utilities"
sudo apt-get install -y -qq --no-upgrade \
  apt-transport-https \
  atop \
  ca-certificates \
  curl \
  git \
  gnupg \
  htop \
  jq \
  lsb-release \
  ncdu \
  rsync \
  silversearcher-ag \
  software-properties-common \
  tmux \
  unzip \
  vim \
  wget \
  zip
ok "Base utilities installed"
