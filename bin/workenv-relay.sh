#!/usr/bin/env bash
# Host-side relay daemon. Listens on a Unix socket for commands from
# containerized tools (xdg-open, notify-send, clipboard) and dispatches them
# to host-native programs.
set -eu

base64_decode() {
  if base64 --help 2>&1 | grep -q -- '-d'; then
    base64 -d
  else
    base64 -D
  fi
}

clipboard_set() {
  if [[ -n "${WORKENV_RELAY_CLIPBOARD_SET:-}" ]]; then
    ${WORKENV_RELAY_CLIPBOARD_SET}
  elif command -v pbcopy >/dev/null 2>&1; then
    pbcopy
  elif command -v wl-copy >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    wl-copy
  elif command -v xclip >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    xclip -selection clipboard
  elif command -v xsel >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    xsel --clipboard --input
  elif command -v clip.exe >/dev/null 2>&1; then
    clip.exe
  else
    echo "workenv-relay: no host clipboard setter found" >&2
    return 1
  fi
}

clipboard_get() {
  if [[ -n "${WORKENV_RELAY_CLIPBOARD_GET:-}" ]]; then
    ${WORKENV_RELAY_CLIPBOARD_GET}
  elif command -v pbpaste >/dev/null 2>&1; then
    pbpaste
  elif command -v wl-paste >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    wl-paste --no-newline
  elif command -v xclip >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    xclip -selection clipboard -o
  elif command -v xsel >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    xsel --clipboard --output
  elif command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command Get-Clipboard | tr -d '\r'
  else
    echo "workenv-relay: no host clipboard getter found" >&2
    return 1
  fi
}

# Detect defaults per platform if not overridden
case "$(uname -s)" in
  Linux*)
    : "${WORKENV_RELAY_SOCK:=${XDG_RUNTIME_DIR:-/tmp}/workenv-relay.sock}"
    : "${WORKENV_RELAY_OPENER:=xdg-open}"
    : "${WORKENV_RELAY_NOTIFIER:=notify-send}"
    ;;
  Darwin*)
    : "${WORKENV_RELAY_SOCK:=${TMPDIR:-/tmp}workenv-relay.sock}"
    : "${WORKENV_RELAY_OPENER:=open}"
    : "${WORKENV_RELAY_NOTIFIER:=osascript -e \"display notification \\\"\$1\\\"\"}"
    ;;
  *)
    : "${WORKENV_RELAY_SOCK:=/tmp/workenv-relay.sock}"
    : "${WORKENV_RELAY_OPENER:=xdg-open}"
    : "${WORKENV_RELAY_NOTIFIER:=echo}"
    ;;
esac

rm -f "$WORKENV_RELAY_SOCK"

handle_line() {
  local line="$1"
  local cmd arg
  cmd="${line%% *}"
  arg="${line#* }"
  case "$cmd" in
    open)
      ${WORKENV_RELAY_OPENER} "$arg" >/dev/null 2>&1 &
      ;;
    notify)
      ${WORKENV_RELAY_NOTIFIER} "$arg" >/dev/null 2>&1 &
      ;;
    clipboard-set)
      printf '%s' "$arg" | base64_decode | clipboard_set
      ;;
    clipboard-get)
      clipboard_get | base64 | tr -d '\n'
      ;;
    *)
      printf 'workenv-relay: unknown command "%s"\n' "$cmd" >&2
      ;;
  esac
}

# socat spawns a shell per connection; the shell reads one line and dispatches.
export -f handle_line
exec socat UNIX-LISTEN:"$WORKENV_RELAY_SOCK",fork,mode=600 \
  SYSTEM:'read -r line; handle_line "$line"'
