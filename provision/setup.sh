#!/usr/bin/env bash
#
# setup.sh
#
# Idempotent system customization for Ubuntu servers. Safe to re-run:
# first run installs everything, subsequent runs update.
#
# Invoked day-to-day via `bin/dotfiles`. Assumes the repo is already
# cloned to ~/.dotfiles.
#
# Optional environment variables:
#   SWAP_SIZE_GB  defaults to 2
#

set -euo pipefail

source "${HOME}/.dotfiles/lib/config.sh"

SYSTEM_DIR="${DOTFILES}/provision/system"
SOFTWARE_DIR="${DOTFILES}/provision/software"
SHELL_DIR="${DOTFILES}/provision/shell"
LOG_FILE="$LOG_SETUP"

mkdir -p "$LOG_DIR"
rm -f "$LOG_SETUP_COMPLETE"
exec > >(tee "$LOG_FILE") 2>&1

# --- Pre-flight checks -------------------------------------------------------

section "Pre-flight checks"

if [[ $EUID -eq 0 ]]; then
  die "Run this script as your administrative user (with sudo), not as root."
fi

if ! sudo -n true 2>/dev/null; then
  info "This script needs sudo. You may be prompted for your password."
  sudo -v
fi

if ! grep -qi 'ubuntu' /etc/os-release; then
  warn "This script targets Ubuntu. Detected:"
  grep PRETTY_NAME /etc/os-release >&2
  exit 1
fi

ok "Running as $(whoami) on $(lsb_release -ds)"

export DEBIAN_FRONTEND=noninteractive

# --- Run modules --------------------------------------------------------------

source "${SYSTEM_DIR}/update.sh"
source "${SYSTEM_DIR}/utilities.sh"
source "${SYSTEM_DIR}/defaults.sh"
source "${SYSTEM_DIR}/security.sh"
source "${SOFTWARE_DIR}/nodejs.sh"
source "${SOFTWARE_DIR}/composer.sh"
source "${SHELL_DIR}/zsh.sh"

# --- Done ---------------------------------------------------------------------

section "Setup complete"
date > "$LOG_SETUP_COMPLETE"
echo "Log: ${LOG_FILE}"
