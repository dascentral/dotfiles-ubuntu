# Ubuntu dotfiles

Personal dotfiles and infrastructure-as-text for Ubuntu servers running Laravel applications.

## Installation

Clone the repository and run the setup script.

```bash
git clone https://github.com/dascentral/ubuntu-dotfiles.git ~/.dotfiles
cd ~/.dotfiles/provision
./setup.sh
```

This installs base utilities, configures system defaults (timezone, journald, swap), sets up security (UFW, Fail2Ban, unattended upgrades), and configures the shell (zsh, Oh My Zsh, plugins, dotfile symlinks).

For Laravel app servers, run the provisioning script after setup:

```bash
./provision-laravel-app-server.sh
```

This adds Nginx, PHP-FPM, MySQL 8.4 LTS, Redis, Supervisor, Composer, and Node.js. See `provision/README.md` for the full how-to guide.

## Staying up-to-date

The `dotfiles` command pulls the latest repo changes and re-runs `setup.sh`. It lives in `~/.dotfiles/bin` and can be executed from anywhere.

```bash
dotfiles
```
