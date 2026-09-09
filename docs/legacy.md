# Legacy Scripts

The provisioning script (created April 2026) replaces many of these. Do not conflate the two sets of code.

## What They Are

- `install.sh` — interactive prompts, installs older PHP set (8.0-8.3)
- `install/*.sh` — one-shot installers (utilities, certbot, supervisor, nginx, mysql, php, composer, redis, oh-my-zsh)
- `maintain/*.sh` — recurring updates invoked by `bin/dotfiles`
- `bin/dotfiles` — recurring maintenance entrypoint (git pull + apt upgrade + composer + oh-my-zsh refresh)

All assume the repo is cloned to `~/.dotfiles`.

## When to Touch These

Only when explicitly maintaining the legacy flow. New server setup or provisioning logic goes in `provision/`.
