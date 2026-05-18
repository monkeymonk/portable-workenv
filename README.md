# workenv

A portable, Docker-based terminal development environment packaging Neovim 0.12, tmux, and zsh into a single container image. One image, one shared volume, one container per project. Runs on Linux, macOS, and WSL2.

## What it is

workenv is a self-contained development workspace that isolates your editor, shell, multiplexer, and language runtimes inside a Docker container while keeping your project files on the host via bind mounts. It ships with a curated Neovim configuration (27 plugin specs), oh-my-zsh with 13 plugins, tmux with session persistence, and a runtime manager (mise) -- all wired together with XDG-compliant paths and a shared Docker volume.

The goal: run `shellc ~/my-project` and land in a fully configured workspace with LSP, completion, formatters, debugger, Git integration, and clipboard passthrough -- on any machine with Docker.

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

### Neovim plugins (27 specs)

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

## Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/monkeymonk/portable-workenv/main/install.sh | bash
shellc ~/my-project                          # first run builds the image
```

The installer clones the repo to `~/.local/share/workenv`, symlinks the launchers into `~/.local/bin/`, and (with your confirmation) appends a PATH block to your shell rc files (bash, zsh, fish). Re-run `install.sh` to update.

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

First launch of `shellc` builds the Docker image (~5 min) and seeds the volume. Subsequent launches are instant.

## Launchers

| Command | What it does |
|---------|-------------|
| `shellc [dir]` | Interactive zsh session in the project container |
| `tmuxc [dir]` | tmux session with resurrect/continuum persistence |
| `nvimc [dir] [files...]` | Neovim with host→container path translation |

All launchers share the same flag interface and lifecycle: they create the container on first use, then `exec` into it on subsequent calls.

```bash
nvimc ~/my-project src/main.lua    # opens /workspace/src/main.lua inside container
tmuxc ~/my-project                 # attaches to tmux session "my-project"
shellc ~/my-project                # drops into zsh at /workspace
```

## Flags

All launchers accept these flags before the project directory:

```
--ssh-keys           Mount ~/.ssh read-only (fallback when agent forwarding fails)
--docker             Mount /var/run/docker.sock into container
--mount <path>       Extra bind mount → /extra/<basename>
--env <name|k=v>     Pass an environment variable into the container
--override-config    Mount a custom nvim config directory
--name <name>        Override container name (default: workenv-<basename>-<hash>)
--rebuild            Force image rebuild regardless of Dockerfile hash
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
WORKENV_NVIM_CONFIG="/home/me/my-nvim"
WORKENV_NAME="my-project"
```

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
works. Add a `.dockerignore` to keep it small. The launcher tracks the
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
shellc ~/proj        # 1st call: docker run -d (creates workenv-proj-<hash>)
shellc ~/proj        # 2nd call: docker exec   (reuses workenv-proj-<hash>)
# Container stops or disappears → next call recreates it
# Volume persists across container recreation
```

The container runs `sleep infinity` as its entrypoint PID. Each `shellc`/`tmuxc`/`nvimc` call does `docker exec` with the real entrypoint, which sets up the environment and execs the requested tool.

If the image, project path, mounts, config overlays, or forwarded environment
change, the launcher recreates the project container automatically so runtime
settings match the current command.

### Auto-rebuild

Launchers track a SHA-256 hash of the Dockerfile. If it changes, the image rebuilds automatically on next launch. Force a rebuild with `--rebuild`.

## Management

```bash
workenv-stop ~/proj      # stop a specific project's container
workenv-stop --all       # stop all workenv-* containers
workenv-clean            # remove stopped containers + dangling images
```

## Multi-project

Each project gets its own container (`workenv-<sanitized-basename>-<path-hash>`), but all share the `workenv-root` volume. Install a runtime in one project and it's immediately available in all others.

```bash
shellc ~/work/api        # terminal 1 → workenv-api
shellc ~/work/frontend   # terminal 2 → workenv-frontend
```

See [docs/multi-project.md](docs/multi-project.md) for details on shared state boundaries.

## Host integration

**SSH agent:** Forwarded automatically via `$SSH_AUTH_SOCK`. Use `--ssh-keys` to mount `~/.ssh` as a fallback.

**Git config:** `~/.gitconfig` is auto-mounted read-only.

**Environment:** `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` are passed through
automatically when set and are used as Docker build args. Use `--env NAME`,
`--env NAME=value`, or `WORKENV_ENV` for other values.

**Clipboard:** When the host relay is available, Neovim uses the native host
clipboard (`wl-copy`/`xclip`/`pbcopy`/`clip.exe`) through the mounted relay
socket. If the relay is unavailable, it falls back to OSC 52 copy-only
passthrough through Neovim → tmux → host terminal.

**Host relay (optional):** Start `bin/workenv-relay.sh` on the host to enable `xdg-open` and `notify-send` passthrough from inside the container. Container shims (sourced from `share/shims/`) detect the relay socket and degrade gracefully if unavailable.

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
  shellc, tmuxc, nvimc          # launchers (on PATH)
  workenv-stop, workenv-clean   # management helpers
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
