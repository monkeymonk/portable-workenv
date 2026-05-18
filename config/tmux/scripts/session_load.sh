#!/usr/bin/env bash
set -eu
tmux_session="$(tmux display-message -p '#S')"
in="$XDG_STATE_HOME/tmux/sessions/${tmux_session}.txt"
if [[ ! -f "$in" ]]; then
  tmux display-message "tmux: no saved session at $in"
  exit 0
fi
while IFS=' ' read -r idx name path; do
  tmux new-window -t "$tmux_session:$idx" -n "$name" -c "$path" 2>/dev/null || true
done < "$in"
tmux display-message "tmux: session loaded"
