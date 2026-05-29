#!/usr/bin/env bash
# install.sh — install workenv. Two modes, picked automatically:
#
#   1. Remote:  clone https://github.com/monkeymonk/portable-workenv into
#               $WORKENV_HOME (~/.local/share/workenv by default), then symlink
#               launchers into $WORKENV_BIN. Re-run to git-pull and refresh.
#               Triggered by the one-liner:
#                 curl -fsSL https://.../install.sh | bash
#
#   2. Local:   when install.sh is invoked from inside an existing workenv
#               source tree (i.e. you cloned/forked the repo and run
#               `bash ./install.sh` from there), no clone happens — the source
#               tree IS the install. Launchers are symlinked from $SCRIPT_DIR.
#               A .workenv-local-install marker is dropped so uninstall.sh
#               won't rm -rf your working tree.
#
# Override defaults with env vars:
#   WORKENV_REPO   git URL (remote mode only; default: monkeymonk/portable-workenv)
#   WORKENV_HOME   install location (remote mode only; default: ~/.local/share/workenv)
#   WORKENV_BIN    where to symlink launchers (default: ~/.local/bin)
#   WORKENV_REF    branch/tag/commit to check out (remote mode only; default: main)

set -euo pipefail

: "${WORKENV_REPO:=https://github.com/monkeymonk/portable-workenv.git}"
: "${WORKENV_HOME:=$HOME/.local/share/workenv}"
: "${WORKENV_BIN:=$HOME/.local/bin}"
: "${WORKENV_REF:=main}"

# Resolve the directory containing this script when invoked from a file.
# When piped (curl | bash) BASH_SOURCE points to nothing useful — leave blank.
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR=""
fi

CORE_LAUNCHERS=(workenv workenv-relay.sh)
LEGACY_LAUNCHERS=(shellc tmuxc nvimc workenv-stop workenv-clean)
MARKER_START='# >>> workenv path >>>'
MARKER_END='# <<< workenv path <<<'

log()  { printf 'workenv-install: %s\n' "$*" >&2; }
die()  { printf 'workenv-install: error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"; }

read_tty() {
  # Prompt on stderr, read from /dev/tty so it works under `curl | bash`.
  # If no controlling tty is available, return the default silently.
  local prompt="$1" default="${2:-N}" reply
  if ! { exec 3</dev/tty; } 2>/dev/null; then
    printf '%s\n' "$default"
    return 0
  fi
  printf '%s ' "$prompt" >&2
  IFS= read -r reply <&3 || reply=""
  exec 3<&-
  printf '%s\n' "${reply:-$default}"
}

path_contains() {
  case ":$PATH:" in *":$1:"*) return 0 ;; esac
  return 1
}

is_workenv_source_tree() {
  local dir="$1"
  [[ -n "$dir" ]] || return 1
  [[ -f "$dir/bin/workenv" ]] || return 1
  [[ -f "$dir/libexec/_workenv-lib.sh" ]] || return 1
  [[ -f "$dir/Dockerfile" ]] || return 1
  return 0
}

clone_or_update() {
  if [[ -d "$WORKENV_HOME/.git" ]]; then
    log "updating $WORKENV_HOME"
    git -C "$WORKENV_HOME" fetch --depth 1 origin "$WORKENV_REF"
    git -C "$WORKENV_HOME" checkout -q "$WORKENV_REF"
    git -C "$WORKENV_HOME" reset --hard -q "origin/$WORKENV_REF" 2>/dev/null \
      || git -C "$WORKENV_HOME" reset --hard -q "$WORKENV_REF"
  else
    log "cloning $WORKENV_REPO → $WORKENV_HOME"
    mkdir -p "$(dirname "$WORKENV_HOME")"
    git clone --depth 1 --branch "$WORKENV_REF" "$WORKENV_REPO" "$WORKENV_HOME"
  fi
}

local_install() {
  log "local install: using $WORKENV_HOME directly (no clone)"
  : > "$WORKENV_HOME/.workenv-local-install"
}

# True when WORKENV_BIN is the install's own bin/ (e.g. the user already puts
# $WORKENV_HOME/bin on PATH and points WORKENV_BIN at it). Symlinking would be a
# no-op (source == target), so we skip it.
bin_is_install_dir() {
  [[ -d "$WORKENV_BIN" && -d "$WORKENV_HOME/bin" && "$WORKENV_BIN" -ef "$WORKENV_HOME/bin" ]]
}

link_core_launchers() {
  if bin_is_install_dir; then
    log "$WORKENV_BIN is the install's own bin/ — launchers already there, skipping symlinks"
    return 0
  fi
  mkdir -p "$WORKENV_BIN"
  local tool
  for tool in "${CORE_LAUNCHERS[@]}"; do
    [[ -x "$WORKENV_HOME/bin/$tool" ]] || die "launcher missing: bin/$tool"
    ln -sfn "$WORKENV_HOME/bin/$tool" "$WORKENV_BIN/$tool"
  done
  log "symlinked ${#CORE_LAUNCHERS[@]} core launchers in $WORKENV_BIN"
}

maybe_link_legacy_aliases() {
  if bin_is_install_dir; then
    return 0  # aliases already live in WORKENV_BIN (= install bin/)
  fi
  local already=0 tool
  for tool in "${LEGACY_LAUNCHERS[@]}"; do
    [[ -L "$WORKENV_BIN/$tool" ]] && already=$((already + 1))
  done
  if [[ $already -eq ${#LEGACY_LAUNCHERS[@]} ]]; then
    log "legacy aliases already installed: ${LEGACY_LAUNCHERS[*]}"
    for tool in "${LEGACY_LAUNCHERS[@]}"; do
      ln -sfn "$WORKENV_HOME/bin/$tool" "$WORKENV_BIN/$tool"
    done
    return 0
  fi

  log "legacy aliases (${LEGACY_LAUNCHERS[*]}) are short forms of 'workenv <subcommand>'"
  local reply
  reply="$(read_tty 'Symlink legacy aliases too? [y/N]' N)"
  case "$reply" in
    y|Y|yes|YES)
      for tool in "${LEGACY_LAUNCHERS[@]}"; do
        [[ -x "$WORKENV_HOME/bin/$tool" ]] || die "launcher missing: bin/$tool"
        ln -sfn "$WORKENV_HOME/bin/$tool" "$WORKENV_BIN/$tool"
      done
      log "symlinked ${#LEGACY_LAUNCHERS[@]} legacy aliases"
      ;;
    *)
      log "skipped legacy aliases. Use 'workenv shell|tmux|edit|stop|clean'."
      ;;
  esac
}

detect_rc_files() {
  # Print one "shell:path" per existing rc file.
  [[ -f "$HOME/.bashrc" ]]                  && printf 'bash:%s\n' "$HOME/.bashrc"
  [[ -f "$HOME/.zshrc" ]]                   && printf 'zsh:%s\n'  "$HOME/.zshrc"
  [[ -f "$HOME/.config/fish/config.fish" ]] && printf 'fish:%s\n' "$HOME/.config/fish/config.fish"
}

write_path_block() {
  local shell="$1" file="$2"
  if grep -qF "$MARKER_START" "$file"; then
    log "  $file already configured"
    return 0
  fi
  local line
  case "$shell" in
    bash|zsh) line="export PATH=\"$WORKENV_BIN:\$PATH\"" ;;
    fish)     line="fish_add_path \"$WORKENV_BIN\"" ;;
    *)        die "unsupported shell: $shell" ;;
  esac
  {
    printf '\n%s\n' "$MARKER_START"
    printf '# Managed by workenv install.sh — run uninstall.sh from your workenv install, or delete this block.\n'
    printf '%s\n' "$line"
    printf '%s\n' "$MARKER_END"
  } >> "$file"
  log "  added PATH block to $file"
}

maybe_setup_path() {
  if path_contains "$WORKENV_BIN"; then
    log "$WORKENV_BIN already on PATH"
    return 0
  fi
  log "$WORKENV_BIN is NOT on your PATH"

  local rcs=() line
  while IFS= read -r line; do
    rcs+=("$line")
  done < <(detect_rc_files)
  if [[ ${#rcs[@]} -eq 0 ]]; then
    log "no bash/zsh/fish rc files detected; add this manually:"
    log "  export PATH=\"$WORKENV_BIN:\$PATH\""
    return 0
  fi

  log "detected shell rc files:"
  local entry
  for entry in "${rcs[@]}"; do log "  - ${entry#*:}"; done

  local reply
  reply="$(read_tty 'Add PATH block to these files? [y/N]' N)"
  case "$reply" in
    y|Y|yes|YES)
      for entry in "${rcs[@]}"; do
        write_path_block "${entry%%:*}" "${entry#*:}"
      done
      log "restart your shell or 'source' the rc file to pick up PATH"
      ;;
    *)
      log "skipped. To enable manually, add:"
      log "  export PATH=\"$WORKENV_BIN:\$PATH\""
      ;;
  esac
}

main() {
  need git
  need docker
  if ! docker info >/dev/null 2>&1; then
    log "warning: 'docker info' failed — daemon not running or user lacks permissions"
  fi
  if ! command -v socat >/dev/null 2>&1; then
    log "warning: 'socat' not found — host relay won't start; Neovim clipboard paste from host will not work."
    log "  install: 'sudo pacman -S socat' / 'sudo apt install socat' / 'brew install socat'"
  fi

  if is_workenv_source_tree "$SCRIPT_DIR"; then
    if [[ -d "$WORKENV_HOME" && "$WORKENV_HOME" != "$SCRIPT_DIR" ]]; then
      log "note: a previous install exists at $WORKENV_HOME — this run will not touch it."
      log "      remove it once you've verified the new install: rm -rf $WORKENV_HOME"
    fi
    WORKENV_HOME="$SCRIPT_DIR"
    local_install
  else
    clone_or_update
  fi
  link_core_launchers
  maybe_link_legacy_aliases
  maybe_setup_path
  log "done. Try: workenv shell <some-project-dir>"
}

main "$@"
