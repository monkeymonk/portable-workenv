# workenv

A portable, Docker-based terminal development environment packaging Neovim 0.12, tmux, and zsh into a single container image. One image, one shared volume, one container per project. Runs on Linux, macOS, and WSL2.

## What it is

workenv is a self-contained development workspace that isolates your editor, shell, multiplexer, and language runtimes inside a Docker container while keeping your project files on the host via bind mounts. It ships with a curated Neovim configuration (27 plugin spec files; ~39 underlying repos), oh-my-zsh with 13 plugins, tmux with session persistence, and a runtime manager (mise) -- all wired together with XDG-compliant paths and a shared Docker volume.

The goal: run `workenv shell ~/my-project` and land in a fully configured workspace with LSP, completion, formatters, debugger, Git integration, and clipboard passthrough -- on any machine with Docker.

## What's inside

| Layer | Key components |
|-------|---------------|
| **Base** | Debian 12 slim, non-root `dev` user with host UID/GID mapping |
| **CLI tools** | ripgrep 14.1, fd 10.2, fzf 0.56, bat 0.24, delta 0.18, zoxide 0.9, chafa, jq, tree, socat |
| **Editor** | Neovim 0.12.0 with `vim.pack.add()` native package loading |
| **Shell** | zsh + oh-my-zsh (13 plugins including vi-mode, autosuggestions, syntax-highlighting) |
| **Multiplexer** | tmux + TPM (8 plugins: sensible, vim-navigator, yank, resurrect, continuum, floax, catppuccin) |
| **Runtimes** | mise + Node LTS 22.11 pre-baked; Mason for LSP servers, formatters, linters |
| **Theme** | Catppuccin Mocha across Neovim, tmux, fzf, and bat |

### Neovim plugins (27 spec files)

**Core:** catppuccin, lualine, snacks (dashboard/picker/explorer/notifier/indent), which-key, noice

**Code intelligence:** mason + mason-lspconfig + mason-tool-installer, blink.cmp, lspsaga, lsp-lines, treesitter (22 parsers), conform (format-on-save), nvim-lint

**Git:** gitsigns, neogit + diffview, comment + ts-context-commentstring

**Editing:** mini-pairs, mini-surround, mini-move, yanky, persistence, window-picker, neogen, log-highlight

**Markdown:** render-markdown, markdown-plus

**Integration:** tmux-navigator, dap (PHP/Node/Chrome adapters)

14 LSP server configs ship out of the box (lua_ls, ts_ls, html, cssls, jsonls, yamlls, bashls, dockerls, intelephense, pyright, gopls, rust_analyzer, tailwindcss, emmet_ls).

## Architecture

```
Host                              Container (workenv-<project>)
─────────────────────────         ─────────────────────────────
~/my-project ──bind mount──────→  /workspace
workenv-root volume ───────────→  /home/dev/.local/share/workenv-root/
                                    ├── config/   (nvim, tmux, shell, mise)
                                    ├── data/     (plugins, parsers, runtimes)
                                    ├── state/    (sessions, history)
                                    └── cache/
$SSH_AUTH_SOCK ──────────────→    /run/host-ssh/agent.sock
~/.gitconfig ────read-only────→   /home/dev/.gitconfig
relay socket (optional) ──────→   /run/host-relay/open.sock
```

All persistent state lives in a single Docker volume (`workenv-root`). Plugins, parsers, mise runtimes, tmux plugins, shell history, and sessions are shared across every project container.

The entrypoint seeds default configs into the volume on first run using `cp -an` (no-clobber), so user edits are preserved across image rebuilds.

## Requirements (host)

Install these on the host **before** running `install.sh`. The installer prints
a warning for each missing one but won't fail.

| Tool    | Why                                                                | Install                                                          |
|---------|--------------------------------------------------------------------|------------------------------------------------------------------|
| `docker` | Builds and runs the image                                          | distro pkg / Docker Desktop                                      |
| `git`    | Used by `install.sh` (remote mode) and inside the container        | distro pkg                                                       |
| `socat`  | **Required for clipboard paste and `xdg-open`/`notify-send` from the container.** Without it, Neovim falls back to OSC 52 copy-only and host-aware shims don't reach the host. | `sudo pacman -S socat` / `sudo apt install socat` / `brew install socat` |

The container itself bundles its own `socat`, ripgrep, fd, fzf, bat, etc. — you
only need the three above on the host.

## Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/monkeymonk/portable-workenv/main/install.sh | bash
workenv shell ~/my-project                   # first run builds the image
```

The installer clones the repo to `~/.local/share/workenv`, symlinks the `workenv`
and `workenv-relay.sh` launchers into `~/.local/bin/`, prompts before adding the
legacy short aliases (`shellc`, `tmuxc`, `nvimc`, `workenv-stop`, `workenv-clean`),
and (with your confirmation) appends a PATH block to your shell rc files
(bash, zsh, fish). Re-run `install.sh` to update.

### Local (in-place) install

If you've already cloned or forked the repo and want to develop against it
directly, just run the installer from inside the source tree:

```bash
bash /path/to/portable-workenv/install.sh
```

The installer detects the source tree, skips the clone, and symlinks the
launchers straight to the working copy. A `.workenv-local-install` marker is
written so `uninstall.sh` won't `rm -rf` your working tree. Every future edit
in the source is immediately live — no re-deploy.

To audit before running:

```bash
curl -fsSL https://raw.githubusercontent.com/monkeymonk/portable-workenv/main/install.sh -o /tmp/workenv-install.sh
less /tmp/workenv-install.sh && bash /tmp/workenv-install.sh
```

Override defaults with env vars: `WORKENV_HOME` (install location), `WORKENV_BIN` (symlink target), `WORKENV_REPO` (fork URL), `WORKENV_REF` (branch/tag).

To uninstall:

```bash
bash ~/.local/share/workenv/uninstall.sh
```

First launch of `workenv shell` builds the Docker image (~5 min) and seeds the volume. Subsequent launches are instant.

## Launchers

Everything is one binary: `workenv <subcommand> [opts] [args]`. Subcommands share
the same flag interface and lifecycle — they create the container on first use,
then `exec` into it on subsequent calls.

| Command | What it does |
|---------|-------------|
| `workenv shell [dir]`              | Interactive zsh session in the project container |
| `workenv tmux  [dir]`              | tmux session with resurrect/continuum persistence |
| `workenv edit  [dir] [files...]`   | Neovim with host→container path translation |
| `workenv stop  [name\|dir\|--all]` | Stop project container(s) by path, full name, or basename prefix |
| `workenv clean`                    | Remove stopped `workenv-*` containers + dangling images |
| `workenv restart [dir]`            | Force-recreate the project container |
| `workenv help`                     | Show usage |

```bash
workenv edit  ~/my-project src/main.lua  # opens /workspace/src/main.lua inside container
workenv tmux  ~/my-project               # attaches to tmux session "my-project"
workenv shell ~/my-project               # drops into zsh at /workspace
```

### Legacy short aliases (opt-in)

`shellc`, `tmuxc`, `nvimc`, `workenv-stop`, and `workenv-clean` are thin shims
over the subcommands above. `install.sh` will ask whether to symlink them; if
you prefer typing less, accept. They behave identically to `workenv <subcmd>`.

## Flags

All subcommands accept these flags before the project directory:

```
--ssh-keys           Mount ~/.ssh read-only (fallback when agent forwarding fails)
--docker             Mount /var/run/docker.sock into container
--mount <path>       Extra bind mount → /extra/<basename>
--env <name|k=v>     Pass an environment variable into the container
--config <app>=<path>  Mount your own config for an app (nvim|zsh|tmux), read-only
--override-config <path>  Alias for --config nvim=<path>
--name <name>        Override container name (default: workenv-<basename>-<hash>)
--rebuild            Force image rebuild regardless of Dockerfile hash
--force-restart      Recreate the container on spec drift without prompting
--no-restart         Refuse to recreate on spec drift (exits with an error)
```

## Configuration

### Global config

`~/.config/workenv/config`:

```bash
WORKENV_IMAGE="workenv:latest"
WORKENV_SSH_KEYS=true
WORKENV_DOCKER=false
WORKENV_EXTRA_MOUNTS="/home/me/shared-libs"
WORKENV_ENV="GITHUB_TOKEN HTTPS_PROXY=http://proxy.example"
WORKENV_NVIM_CONFIG="/home/me/.config/nvim"   # bring your own nvim config
WORKENV_ZSH_CONFIG="/home/me/.config/zsh"     # bring your own zsh config
WORKENV_TMUX_CONFIG="/home/me/.config/tmux"   # bring your own tmux config
WORKENV_NAME="my-project"
```

### Config layers: core, config, local

Each app's config is composed in three layers, so you can run with our defaults,
tweak them, or bring your own entirely — while host integration always works:

- **core** — host integration (clipboard relay, `gx`/open routing, tmux
  passthrough) baked into the image and loaded for *any* config, including your
  own. The `nvim` wrapper injects it onto `packpath`; tmux is started with the
  baked core conf which then sources your config. Opt out per-tool with
  `vim.g.workenv_core_clipboard=false` / `vim.g.workenv_core_open=false`, or
  disable the nvim injection with `WORKENV_NVIM_NO_CORE=1`.
- **config** — the opinionated, swappable layer: ours by default, or bring your
  own via `--config <app>=<path>` / `WORKENV_<APP>_CONFIG` / per-project
  `.workenv/config/<app>/`. Host-global overrides beat per-project overlays.
- **local** — small additive tweaks without forking, kept in the volume
  (survive rebuilds, gitignore them): `lua/config/user.lua` (nvim, loaded last),
  `$ZDOTDIR/.zshrc.local` (zsh), `tmux.local.conf` (tmux).

### Per-project: the `.workenv/` directory

Drop a `.workenv/` directory at a project root (gitignore it) to customise
that project's container without forking the repo. Everything is optional.

```
my-project/
  .workenv/
    env                   # shell file: WORKENV_DOCKER=true, etc.
    Dockerfile            # extends workenv:latest (see below)
    config/
      nvim/               # overlay over the volume's nvim config (read-only)
      tmux/               # same for tmux
      zsh/                # same for zsh
```

`env` is sourced by the launcher; per-project values override global, CLI
flags override both. See `share/examples/.workenv/` for a fully documented
template.

#### Project Dockerfile (image extension)

If `.workenv/Dockerfile` exists, the launcher builds a derived image
`workenv:<project>` (extending `workenv:latest`) and runs that project's
container from it instead of the base. Add per-project tooling here without
forking the repo.

```dockerfile
# .workenv/Dockerfile
FROM workenv:latest
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
      postgresql-client redis-tools \
 && rm -rf /var/lib/apt/lists/*
USER dev
```

Build context is the **project root**, so `COPY ./pyproject.toml /app/`
works. Add a `.dockerignore` to keep it small — the launcher warns once
per project when the context exceeds ~100 MB and neither
`./.dockerignore` nor `./.workenv/.dockerignore` is present (tune the
threshold with `WORKENV_DOCKERIGNORE_WARN_MB`). The launcher tracks the
Dockerfile's SHA-256; rebuilds happen automatically on change. Force one
with `--rebuild`.

#### Project config overlays

If `.workenv/config/<app>/` exists (any of `nvim`, `tmux`, `zsh`), it is
mounted read-only over the volume's bundled config for that app, replacing
it for this project only. Layout mirrors `~/.config/<app>/`.

### Custom Neovim config (host-wide)

For overrides that aren't per-project: `--override-config <path>` flag, or
`WORKENV_NVIM_CONFIG=<path>` in global config. Typically:
`--override-config $HOME/.config/nvim`. The repo's `config/nvim/` mirrors
`~/.config/nvim/` 1:1, so a fork or symlink works without path translation.

## Container lifecycle

```
workenv shell ~/proj   # 1st call: docker run -d (creates workenv-proj-<hash>)
workenv shell ~/proj   # 2nd call: docker exec   (reuses workenv-proj-<hash>)
# Container stops or disappears → next call recreates it
# Volume persists across container recreation
```

The container runs `sleep infinity` as its entrypoint PID. Each `workenv` call
does `docker exec` with the real entrypoint, which sets up the environment and
execs the requested tool.

### Spec drift and recreation

If the image, mounts, or forwarded environment differ from what the running
container was started with, the launcher prints a diff and asks whether to
recreate the container. Recreation kills anything running inside (tmux
sessions, dev servers, debuggers).

```
workenv: container workenv-proj-a1b2c3d4 has drifted from current spec:
  + mount: /home/me/extra:/extra/extra
  + env: GITHUB_TOKEN
workenv: recreate workenv-proj-a1b2c3d4? running processes inside will be killed [y/N]
```

Override the prompt:

- `--force-restart` — recreate without asking
- `--no-restart` — refuse to recreate (exits with an error if drift exists)
- `WORKENV_AUTO_RESTART=yes|no` — the same, non-interactively (useful in scripts)
- `workenv restart [dir]` — explicit recreate, no prompt

### Auto-rebuild

Launchers track a SHA-256 hash of the Dockerfile. If it changes, the image rebuilds automatically on next launch. Force a rebuild with `--rebuild`.

## Management

```bash
workenv stop ~/proj        # stop a specific project's container
workenv stop --all         # stop all workenv-* containers
workenv clean              # remove stopped containers + dangling images
workenv restart ~/proj     # force-recreate the project container
```

## Multi-project

Each project gets its own container (`workenv-<sanitized-basename>-<path-hash>`), but all share the `workenv-root` volume. Install a runtime in one project and it's immediately available in all others.

```bash
workenv shell ~/work/api        # terminal 1 → workenv-api
workenv shell ~/work/frontend   # terminal 2 → workenv-frontend
```

See [docs/multi-project.md](docs/multi-project.md) for details on shared state boundaries.

## Host integration

**SSH agent:** Forwarded automatically via `$SSH_AUTH_SOCK`. Use `--ssh-keys` to mount `~/.ssh` as a fallback.

**Git config:** `~/.gitconfig` is auto-mounted read-only.

**Environment:** `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` are passed through
automatically when set and are used as Docker build args. Use `--env NAME`,
`--env NAME=value`, or `WORKENV_ENV` for other values.

**Clipboard + host relay:** A small host daemon (`bin/workenv-relay.sh`) is
auto-started by the launcher and provides the only path for bidirectional
clipboard sharing between Neovim and the host, plus `xdg-open` and
`notify-send` passthrough from inside the container. Each `workenv` call
prints a one-line notice the first time it starts the daemon.

- **With the relay (default):** Neovim uses the host clipboard
  (`wl-copy`/`xclip`/`pbcopy`/`clip.exe`) for both copy and paste.
- **Without the relay:** Neovim falls back to OSC 52 copy-only passthrough
  through tmux → host terminal — paste from host to Neovim does not work.

Set `WORKENV_RELAY_AUTO_START=false` to disable auto-start (and accept the
copy-only fallback).

The relay sanitises what it forwards: `open` accepts only the URL schemes
listed in `WORKENV_RELAY_OPEN_SCHEMES` (default `http,https,mailto`), and
`notify` passes the message to the host notifier as a single argv element so
container-side strings never reach a shell. Newlines in either argument are
rejected by the container shims.

## Platform support

| Platform | UID/GID | SSH agent | Relay socket location |
|----------|---------|-----------|----------------------|
| Linux | Build-arg mapped | `$SSH_AUTH_SOCK` auto | `$XDG_RUNTIME_DIR/workenv-relay.sock` |
| macOS | Docker Desktop handles it | Docker socket forwarding | `$TMPDIR/workenv-relay.sock` |
| WSL2 | Same as Linux | Same as Linux | Same as Linux |

See per-platform guides: [Linux](docs/linux.md) | [macOS](docs/macos.md) | [WSL2](docs/windows-wsl.md)

## Project structure

```
bin/
  workenv                       # unified launcher (on PATH)
  shellc, tmuxc, nvimc          # legacy aliases for workenv shell|tmux|edit (opt-in)
  workenv-stop, workenv-clean   # legacy aliases for workenv stop|clean (opt-in)
  workenv-relay.sh              # host-side relay daemon
config/                         # mirrors ~/.config — fork or symlink in place
  nvim/
    init.lua                    # entry point
    lua/config/                 # options, keymaps, autocmds, lsp, clipboard, etc.
    lua/plugins/                # 27 plugin spec files (one per plugin/group)
    lua/util/pack/              # vim.pack.add() wrapper with lazy-loading
  zsh/
    zshrc, zprofile             # zsh defaults (oh-my-zsh + 13 plugins)
  tmux/
    tmux.conf                   # tmux defaults (TPM + 8 plugins, catppuccin)
    scripts/                    # session save/load
share/                          # static data (not user-edited)
  shims/                        # xdg-open, notify-send (container relay shims)
  examples/                     # .workenv, mise.toml templates
libexec/                        # internal helpers (not on PATH)
  entrypoint.sh                 # XDG setup, config seeding, exec
  _workenv-lib.sh               # shared launcher library
tests/
  step{1..17}_*.sh              # per-step test scripts
  lib.sh                        # test harness (assert_contains, pass, fail)
docs/                           # setup, platform, multi-project, troubleshooting, extending
install.sh                      # one-line installer (clone + symlink + PATH prompt)
uninstall.sh                    # reverses install.sh; offers docker cleanup
Dockerfile                      # single-stage image definition
```

## Extending

- **Add a plugin:** create `config/nvim/lua/plugins/your-plugin.lua` returning a spec table, rebuild
- **Add an LSP server:** add to `mason.lua` ensure_installed + configure in `config/lsp.lua`
- **Add a formatter/linter:** edit `conform.lua` or `nvim-lint.lua`, add binary to mason-tool-installer
- **Add a system tool:** add to the Dockerfile APT block, rebuild

See [docs/extending.md](docs/extending.md) for full details.

## Docs

- [Setup](docs/setup.md) -- requirements, installation, first run, uninstall
- [Linux](docs/linux.md) -- Docker, SSH agent, systemd relay, clipboard
- [macOS](docs/macos.md) -- Docker Desktop, LaunchAgent relay, performance
- [Windows/WSL](docs/windows-wsl.md) -- WSL2 setup, clipboard, filesystem
- [Multi-project](docs/multi-project.md) -- shared volume model, naming, cleanup
- [Security](docs/security.md) -- mounted dotfiles, secrets, env, Docker socket
- [Troubleshooting](docs/troubleshooting.md) -- common issues and fixes
- [Extending](docs/extending.md) -- adding plugins, servers, tools, forking
