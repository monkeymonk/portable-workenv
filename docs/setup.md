# Setup

## Requirements

- Docker Engine 24+ (Linux/WSL2) or Docker Desktop 4.30+ (macOS)
- `socat` on host (for the relay daemon and tests)
- Bash 4+ in the shell that runs the launchers

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/monkeymonk/portable-workenv/main/install.sh | bash
```

This clones the repo to `~/.local/share/workenv`, symlinks the `workenv`
launcher into `~/.local/bin/`, and (with your confirmation) appends a PATH
block to your shell rc files. Re-run the installer to update.

A default install ships a single entry point, `workenv`, with subcommands:
`workenv shell`, `workenv tmux`, `workenv edit`, `workenv stop`, and
`workenv clean`. The installer also offers (via a y/N prompt) to symlink the
legacy short-form aliases `shellc` / `tmuxc` / `nvimc` / `workenv-stop` /
`workenv-clean`; these are thin opt-in shims that forward to the matching
`workenv <subcommand>`. Unless you accept that prompt, only `workenv` is
installed — the examples in these docs use the canonical `workenv <subcommand>`
form.

Override defaults with env vars before piping:

```bash
WORKENV_HOME=/opt/workenv WORKENV_BIN=/usr/local/bin \
  bash <(curl -fsSL https://raw.githubusercontent.com/monkeymonk/portable-workenv/main/install.sh)
```

### Manual install (audit first, or use a fork)

```bash
git clone https://github.com/monkeymonk/portable-workenv ~/.local/share/workenv
ln -sfn ~/.local/share/workenv/bin/* ~/.local/bin/
# add ~/.local/bin to PATH yourself if not already
```

## First run

```bash
workenv shell ~/some-project
```

Expect the first run to:
1. Build the image (logs visible in terminal, ~5 min).
2. Pull Debian slim + install tools + clone oh-my-zsh + install Node LTS.
3. Seed default configs into the shared volume `workenv-root`.
4. Drop you into `/workspace` as user `dev`.

## Host relay (optional)

To enable `xdg-open`, `notify-send`, and `gx` pass-through, run the daemon:

```bash
workenv-relay.sh &
```

Or auto-start it in your user session. On macOS, use `launchd`. On Linux, a
systemd user unit works. On WSL2, start it from `.bashrc` or via a startup task.

## Global config

`~/.config/workenv/config`

```bash
# All vars optional
WORKENV_IMAGE="workenv:latest"
WORKENV_SSH_KEYS=false
WORKENV_DOCKER=false
WORKENV_EXTRA_MOUNTS=""
WORKENV_ENV=""
WORKENV_NVIM_CONFIG=""
WORKENV_ZSH_CONFIG=""
WORKENV_TMUX_CONFIG=""
WORKENV_NAME=""
# Warn once per project if a .workenv/Dockerfile build context exceeds this
# many MB without a .dockerignore present (default 100).
WORKENV_DOCKERIGNORE_WARN_MB=100
```

`HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` are forwarded automatically when
they are set on the host or in this config file. They are also passed as Docker
build args when images are built. Use `WORKENV_ENV` for other variables:

```bash
WORKENV_ENV="GITHUB_TOKEN FOO=bar"
```

Entries without `=` copy the current value from the host/config shell. Entries
with `=` pass that literal value.

## Config layers

Each app's configuration is assembled from three layers:

- **core** — host integration (clipboard relay, `gx`/open routing) baked into
  the image. It is always loaded for *any* config, even one you bring yourself:
  Neovim is launched through a wrapper that injects the baked core onto
  `packpath`, and tmux is started with `-f /opt/workenv/tmux-core.conf`, which
  then sources your config. So a foreign config still gets host clipboard +
  open. Opt out per tool with `vim.g.workenv_core_clipboard = false` /
  `vim.g.workenv_core_open = false` in your nvim config, or disable the nvim
  core injection entirely with the env var `WORKENV_NVIM_NO_CORE=1`.
- **config** — the swappable opinionated layer: ours by default, or bring your
  own (see below).
- **local** — small additive tweaks that don't require forking the config:
  `lua/config/user.lua` (nvim, loaded last), `$ZDOTDIR/.zshrc.local` (zsh), and
  `tmux.local.conf` (tmux). These live in the shared volume, survive image
  rebuilds, and are yours to gitignore.

## Bring your own config

To replace the **config** layer for a single app, mount a host config
directory read-only over that app's config:

```bash
workenv shell --config nvim=$HOME/.config/nvim
workenv shell --config zsh=$HOME/.config/zsh
workenv shell --config tmux=$HOME/.config/tmux
```

`--override-config <path>` remains an alias for `--config nvim=<path>`.

The env equivalents are `WORKENV_NVIM_CONFIG`, `WORKENV_ZSH_CONFIG`, and
`WORKENV_TMUX_CONFIG` (set them in `.workenv/env` or global config).

The repo's `config/nvim/`, `config/zsh/`, and `config/tmux/` mirror
`~/.config/<app>/` 1:1, so the same config works in both places. Because the
**core** layer is baked into the image, a mounted foreign config still gets the
host clipboard and open routing.

A host-global override (flag or env) beats the per-project
`.workenv/config/<app>/` overlay, which still exists and covers all three apps.

## Custom Docker image name

```bash
WORKENV_IMAGE=myteam/workenv:2024-q4 workenv shell
```

## Custom container name

By default, project containers are named from the project basename plus a short
hash of the absolute path, for example `workenv-api-a1b2c3d4`. This prevents
two different `api` directories from sharing a container accidentally.

Override it with `--name api` or:

```bash
WORKENV_NAME=api
```

## Uninstall

```bash
bash ~/.local/share/workenv/uninstall.sh
```

Removes launcher symlinks, the PATH block (if added), and the install dir.
Prompts before removing the docker image, volume, and containers.
