#!/usr/bin/env bash
# install.sh — clone workenv, symlink launchers, optionally update PATH.
# Re-run to update (git pull).
#
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/monkeymonk/portable-workenv/main/install.sh | bash
#
# Override defaults with env vars:
#   WORKENV_REPO   git URL to clone (default: monkeymonk/portable-workenv)
#   WORKENV_HOME   install location (default: ~/.local/share/workenv)
#   WORKENV_BIN    where to symlink launchers (default: ~/.local/bin)
#   WORKENV_REF    branch/tag/commit to check out (default: main)

set -euo pipefail

: "${WORKENV_REPO:=https://github.com/monkeymonk/portable-workenv.git}"
: "${WORKENV_HOME:=$HOME/.local/share/workenv}"
: "${WORKENV_BIN:=$HOME/.local/bin}"
: "${WORKENV_REF:=main}"

LAUNCHERS=(shellc tmuxc nvimc workenv-stop workenv-clean workenv-relay.sh)
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

link_launchers() {
  mkdir -p "$WORKENV_BIN"
  local tool
  for tool in "${LAUNCHERS[@]}"; do
    [[ -x "$WORKENV_HOME/bin/$tool" ]] || die "launcher missing: bin/$tool"
    ln -sfn "$WORKENV_HOME/bin/$tool" "$WORKENV_BIN/$tool"
  done
  log "symlinked ${#LAUNCHERS[@]} launchers in $WORKENV_BIN"
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
    printf '# Managed by workenv install.sh — uninstall with workenv-uninstall or remove this block.\n'
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
  clone_or_update
  link_launchers
  maybe_setup_path
  log "done. Try: shellc <some-project-dir>"
}

main "$@"
