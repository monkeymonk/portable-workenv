#!/usr/bin/env bash
# uninstall.sh — reverse install.sh. Removes symlinks, install dir, and PATH
# blocks. Optionally removes the docker image, volume, and containers.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/monkeymonk/portable-workenv/main/uninstall.sh)
# or, after a normal install:
#   bash ~/.local/share/workenv/uninstall.sh

set -euo pipefail

: "${WORKENV_HOME:=$HOME/.local/share/workenv}"
: "${WORKENV_BIN:=$HOME/.local/bin}"

LAUNCHERS=(shellc tmuxc nvimc workenv-stop workenv-clean workenv-relay.sh)
MARKER_START='# >>> workenv path >>>'
MARKER_END='# <<< workenv path <<<'

log() { printf 'workenv-uninstall: %s\n' "$*" >&2; }

read_tty() {
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

remove_symlinks() {
  local tool path removed=0
  for tool in "${LAUNCHERS[@]}"; do
    path="$WORKENV_BIN/$tool"
    if [[ -L "$path" ]]; then
      rm -f "$path"
      removed=$((removed + 1))
    fi
  done
  log "removed $removed launcher symlinks from $WORKENV_BIN"
}

remove_path_blocks() {
  local file removed=0
  for file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/fish/config.fish"; do
    [[ -f "$file" ]] || continue
    if grep -qF "$MARKER_START" "$file"; then
      sed -i.workenv-bak "/$MARKER_START/,/$MARKER_END/d" "$file"
      rm -f "$file.workenv-bak"
      log "  cleaned PATH block from $file"
      removed=$((removed + 1))
    fi
  done
  log "removed PATH blocks from $removed file(s)"
}

remove_install_dir() {
  if [[ -d "$WORKENV_HOME" ]]; then
    rm -rf "$WORKENV_HOME"
    log "removed $WORKENV_HOME"
  fi
}

maybe_remove_docker_artifacts() {
  command -v docker >/dev/null 2>&1 || return 0
  local reply
  reply="$(read_tty 'Also remove workenv docker containers, image, and volume? [y/N]' N)"
  case "$reply" in
    y|Y|yes|YES) ;;
    *) log "kept docker artifacts (image, volume, containers)"; return 0 ;;
  esac
  local cids
  cids="$(docker ps -aqf 'name=^workenv-' 2>/dev/null || true)"
  if [[ -n "$cids" ]]; then
    # shellcheck disable=SC2086
    docker rm -f $cids >/dev/null && log "  removed containers"
  fi
  docker volume rm workenv-root >/dev/null 2>&1 && log "  removed volume workenv-root" || true
  local imgs
  imgs="$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^workenv:' || true)"
  if [[ -n "$imgs" ]]; then
    # shellcheck disable=SC2086
    docker image rm -f $imgs >/dev/null && log "  removed workenv:* images"
  fi
}

main() {
  remove_symlinks
  remove_path_blocks
  maybe_remove_docker_artifacts
  remove_install_dir
  log "done."
}

main "$@"
