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

SETUP_DIR="${DOTFILES}/provision/setup"
LOG_FILE="${HOME}/setup.log"

exec > >(tee -a "$LOG_FILE") 2>&1

# --- Pre-flight checks -------------------------------------------------------

section "Pre-flight checks"

if [[ $EUID -eq 0 ]]; then
  echo "Run this script as your administrative user (with sudo), not as root." >&2
  exit 1
fi

if ! sudo -n true 2>/dev/null; then
  echo "This script needs sudo. You may be prompted for your password."
  sudo -v
fi

if ! grep -qi 'ubuntu' /etc/os-release; then
  echo "This script targets Ubuntu. Detected:" >&2
  grep PRETTY_NAME /etc/os-release >&2
  exit 1
fi

ok "Running as $(whoami) on $(lsb_release -ds)"

export DEBIAN_FRONTEND=noninteractive

# --- Run modules --------------------------------------------------------------

source "${SETUP_DIR}/system-update.sh"
source "${SETUP_DIR}/utilities.sh"
source "${SETUP_DIR}/system-defaults.sh"
source "${SETUP_DIR}/security.sh"
source "${SETUP_DIR}/shell.sh"

# --- Done ---------------------------------------------------------------------

section "Setup complete"
echo "Log: ${LOG_FILE}"
