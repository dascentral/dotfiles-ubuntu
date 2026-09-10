# Ubuntu dotfiles

Personal dotfiles and infrastructure-as-text for Ubuntu servers running Laravel applications.

## Installation

Clone the repository and run the setup script.

```bash
git clone https://github.com/dascentral/ubuntu-dotfiles.git ~/.dotfiles
~/.dotfiles/provision/setup.sh
```

## Laravel Application Server

For Laravel app servers, run the provisioning script after setup:

```bash
~/.dotfiles/provision/provision-laravel-app-server.sh
```

## Staying up-to-date

The `dotfiles` command pulls the latest repo changes and re-runs `setup.sh`. It lives in `~/.dotfiles/bin` and can be executed from anywhere.

```bash
dotfiles
```
