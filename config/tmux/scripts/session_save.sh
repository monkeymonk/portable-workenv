#!/usr/bin/env bash
set -eu
mkdir -p "$XDG_STATE_HOME/tmux/sessions"
tmux_session="$(tmux display-message -p '#S')"
out="$XDG_STATE_HOME/tmux/sessions/${tmux_session}.txt"
tmux list-windows -F '#I #W #{pane_current_path}' > "$out"
tmux display-message "tmux: session saved to $out"
