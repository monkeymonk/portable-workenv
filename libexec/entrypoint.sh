#!/usr/bin/env bash
set -eu

# Workspace paths
export WORKENV_ROOT="${WORKENV_ROOT:-/home/dev/.local/share/workenv-root}"
export XDG_CONFIG_HOME="$WORKENV_ROOT/config"
export XDG_DATA_HOME="$WORKENV_ROOT/data"
export XDG_STATE_HOME="$WORKENV_ROOT/state"
export XDG_CACHE_HOME="$WORKENV_ROOT/cache"

export MISE_CONFIG_DIR="$XDG_CONFIG_HOME/mise"
export MISE_DATA_DIR="$XDG_DATA_HOME/mise"
export MISE_STATE_DIR="$XDG_STATE_HOME/mise"
export MISE_CACHE_DIR="$XDG_CACHE_HOME/mise"

# PATH precedence: mise shims > Mason > user-local > system
export PATH="$MISE_DATA_DIR/shims:$XDG_DATA_HOME/nvim/mason/bin:/home/dev/.local/bin:$PATH"

export EDITOR=nvim
export VISUAL=nvim
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export SSH_AUTH_SOCK=/run/host-ssh/agent.sock

# Create directory structure on first run
mkdir -p \
  "$XDG_CONFIG_HOME"/{nvim,tmux,zsh,mise} \
  "$XDG_DATA_HOME"/{nvim,tmux/plugins,mise} \
  "$XDG_STATE_HOME"/{nvim,tmux/sessions,zsh,mise} \
  "$XDG_CACHE_HOME"/{nvim,mise}

# Skip seeding for any config dir that is bind-mounted as a read-only overlay
# (the host already provides the config; cp into a read-only mount would fail).
_is_overlay() { mountpoint -q "$1" 2>/dev/null; }

if ! _is_overlay "$XDG_CONFIG_HOME/zsh"; then
  [[ -e "$XDG_CONFIG_HOME/zsh/.zshrc" ]] \
    || cp -an /opt/workenv-defaults/zsh/zshrc "$XDG_CONFIG_HOME/zsh/.zshrc"
  [[ -e "$XDG_CONFIG_HOME/zsh/.zprofile" ]] \
    || cp -an /opt/workenv-defaults/zsh/zprofile "$XDG_CONFIG_HOME/zsh/.zprofile"
fi

# Seed nvim defaults (no-clobber so user edits in volume are preserved).
_is_overlay "$XDG_CONFIG_HOME/nvim" \
  || cp -an /opt/workenv-defaults/nvim/. "$XDG_CONFIG_HOME/nvim/"

if ! _is_overlay "$XDG_CONFIG_HOME/tmux"; then
  [[ -e "$XDG_CONFIG_HOME/tmux/tmux.conf" ]] \
    || cp -an /opt/workenv-defaults/tmux/. "$XDG_CONFIG_HOME/tmux/"
fi

# Seed TPM into plugin dir if missing
if [[ ! -d "$XDG_DATA_HOME/tmux/plugins/tpm" ]]; then
  cp -r /opt/tpm "$XDG_DATA_HOME/tmux/plugins/tpm"
fi

# Default command: interactive zsh
if [[ $# -eq 0 ]]; then
  exec /usr/bin/zsh
fi

exec "$@"
