# Setup

## Requirements

- Docker Engine 24+ (Linux/WSL2) or Docker Desktop 4.30+ (macOS)
- `socat` on host (for the relay daemon and tests)
- Bash 4+ in the shell that runs the launchers

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/monkeymonk/portable-workenv/main/install.sh | bash
```

This clones the repo to `~/.local/share/workenv`, symlinks launchers into
`~/.local/bin/`, and (with your confirmation) appends a PATH block to your
shell rc files. Re-run the installer to update.

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
shellc ~/some-project
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
WORKENV_NAME=""
```

`HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` are forwarded automatically when
they are set on the host or in this config file. They are also passed as Docker
build args when images are built. Use `WORKENV_ENV` for other variables:

```bash
WORKENV_ENV="GITHUB_TOKEN FOO=bar"
```

Entries without `=` copy the current value from the host/config shell. Entries
with `=` pass that literal value.

## Override the default nvim config

Pass `--override-config $HOME/.config/nvim` to the launcher (or set
`WORKENV_NVIM_CONFIG=$HOME/.config/nvim` in `.workenv` / global config) and
your host nvim config will be mounted read-only over the shipped defaults.
The repo's `config/nvim/` mirrors `~/.config/nvim/` 1:1, so the same config
works in both places.

## Custom Docker image name

```bash
WORKENV_IMAGE=myteam/workenv:2024-q4 shellc
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
