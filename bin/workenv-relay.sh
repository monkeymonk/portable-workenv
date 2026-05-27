#!/usr/bin/env bash
# Host-side relay daemon. Listens on a Unix socket for commands from
# containerized tools (xdg-open, notify-send, clipboard) and dispatches them
# to host-native programs.
#
# Protocol: one line per connection.
#   open <url>            URL must match WORKENV_RELAY_OPEN_SCHEMES (default
#                         http,https,mailto). Other schemes (file:, javascript:,
#                         data:, bare paths) are rejected.
#   notify <msg>          Message is passed as a single argv element to the
#                         host notifier — never interpolated into a shell.
#   clipboard-set <b64>   Base64-encoded payload, decoded then piped to setter.
#   clipboard-get         Returns base64-encoded host clipboard content.
#
# `--dispatch` is an internal flag used to re-exec this script as the per-
# connection handler under `socat ... EXEC`. Users should never invoke it.
set -euo pipefail

base64_decode() {
  if base64 --help 2>&1 | grep -q -- '-d'; then
    base64 -d
  else
    base64 -D
  fi
}

# Default allowlist of URL schemes for `open`. Override with a comma-separated
# list in WORKENV_RELAY_OPEN_SCHEMES.
: "${WORKENV_RELAY_OPEN_SCHEMES:=http,https,mailto}"

url_scheme_allowed() {
  local url="$1" scheme rest
  case "$url" in
    *://*)    scheme="${url%%://*}" ;;
    mailto:*) scheme="mailto" ;;
    *)        return 1 ;;
  esac
  scheme="${scheme,,}"
  local IFS=,
  for rest in $WORKENV_RELAY_OPEN_SCHEMES; do
    rest="${rest,,}"
    rest="${rest## }"; rest="${rest%% }"
    [[ "$scheme" == "$rest" ]] && return 0
  done
  return 1
}

clipboard_set() {
  if [[ -n "${WORKENV_RELAY_CLIPBOARD_SET:-}" ]]; then
    # shellcheck disable=SC2086
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
    # shellcheck disable=SC2086
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

# Platform defaults.
case "$(uname -s)" in
  Linux*)
    : "${WORKENV_RELAY_SOCK:=${XDG_RUNTIME_DIR:-/tmp}/workenv-relay.sock}"
    : "${WORKENV_RELAY_OPENER:=xdg-open}"
    : "${WORKENV_RELAY_NOTIFIER:=notify-send}"
    : "${WORKENV_RELAY_NOTIFY_KIND:=argv}"
    ;;
  Darwin*)
    : "${WORKENV_RELAY_SOCK:=${TMPDIR:-/tmp}workenv-relay.sock}"
    : "${WORKENV_RELAY_OPENER:=open}"
    : "${WORKENV_RELAY_NOTIFIER:=__macos_osascript__}"
    : "${WORKENV_RELAY_NOTIFY_KIND:=macos}"
    ;;
  *)
    : "${WORKENV_RELAY_SOCK:=/tmp/workenv-relay.sock}"
    : "${WORKENV_RELAY_OPENER:=xdg-open}"
    : "${WORKENV_RELAY_NOTIFIER:=echo}"
    : "${WORKENV_RELAY_NOTIFY_KIND:=argv}"
    ;;
esac

# Dispatch a notification message as a single argv element — never embedded in
# a shell string. The macOS path uses osascript's `on run argv` so the message
# cannot escape the AppleScript string literal.
dispatch_notify() {
  local msg="$1"
  case "$WORKENV_RELAY_NOTIFY_KIND" in
    macos)
      /usr/bin/osascript -e 'on run argv
        display notification (item 1 of argv)
      end run' "$msg" >/dev/null 2>&1 &
      ;;
    argv|*)
      # shellcheck disable=SC2086
      ${WORKENV_RELAY_NOTIFIER} "$msg" >/dev/null 2>&1 &
      ;;
  esac
}

handle_line() {
  local line="$1"
  local cmd arg
  cmd="${line%% *}"
  arg="${line#* }"
  [[ "$cmd" == "$line" ]] && arg=""
  case "$cmd" in
    open)
      if ! url_scheme_allowed "$arg"; then
        printf 'workenv-relay: refused open: scheme not in WORKENV_RELAY_OPEN_SCHEMES (%s)\n' "$arg" >&2
        return 0
      fi
      # shellcheck disable=SC2086
      ${WORKENV_RELAY_OPENER} "$arg" >/dev/null 2>&1 &
      ;;
    notify)
      dispatch_notify "$arg"
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

# Per-connection dispatch mode. socat spawns this with the connection on stdio.
if [[ "${1:-}" == "--dispatch" ]]; then
  IFS= read -r line || exit 0
  handle_line "$line"
  exit 0
fi

# If another daemon is already listening on the socket, exit silently. Avoids
# the previous unconditional `rm -f` that race-clobbered concurrent launchers.
if [[ -S "$WORKENV_RELAY_SOCK" ]] \
   && command -v socat >/dev/null 2>&1 \
   && printf '' | socat - "UNIX-CONNECT:$WORKENV_RELAY_SOCK" >/dev/null 2>&1; then
  exit 0
fi
rm -f "$WORKENV_RELAY_SOCK"

# Re-exec ourselves per connection so `set -euo pipefail` and all helpers are
# in scope without relying on `export -f` (which only works under bash).
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
exec socat UNIX-LISTEN:"$WORKENV_RELAY_SOCK",fork,mode=600 \
  EXEC:"$SELF --dispatch"
