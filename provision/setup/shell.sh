#!/usr/bin/env bash
set -euo pipefail

ZSH_CUSTOM="${HOME}/.oh-my-zsh/custom"

section "Shell environment"

sudo apt-get install -y -qq zsh

if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
  RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  ok "Oh My Zsh installed"
else
  ok "Oh My Zsh already installed (self-updates)"
fi

for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
  plugin_dir="${ZSH_CUSTOM}/plugins/${plugin}"
  if [[ -d "${plugin_dir}" ]]; then
    git -C "${plugin_dir}" pull --ff-only --quiet
    ok "${plugin} updated"
  else
    git clone --quiet "https://github.com/zsh-users/${plugin}.git" "${plugin_dir}"
    ok "${plugin} installed"
  fi
done

ln -sf "${DOTFILES}/shell/.zshrc" "${HOME}/.zshrc"
ln -sf "${DOTFILES}/shell/.aliases" "${HOME}/.aliases"
ok "Shell config symlinked"

if [[ "$(getent passwd "$(whoami)" | cut -d: -f7)" != "$(command -v zsh)" ]]; then
  sudo chsh -s "$(command -v zsh)" "$(whoami)"
  ok "Default shell changed to zsh"
else
  ok "Default shell already zsh"
fi
