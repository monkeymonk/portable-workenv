#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

build_image
cleanup_test_volume

# Warm-up for fresh volume (plugins clone)
run_container nvim --headless +qa >/dev/null 2>&1 || true

# Test 1: clipboard=unnamedplus
out=$(run_container nvim --headless +'lua print(vim.o.clipboard)' +qa 2>&1)
assert_contains "$out" "unnamedplus"
pass "clipboard=unnamedplus"

# Test 2: OSC 52 fallback is copy-only to avoid paste response timeouts
out=$(run_container nvim --headless +'lua print((vim.g.clipboard or {}).name or "none")' +qa 2>&1)
assert_contains "$out" "OSC 52"
assert_contains "$out" "copy-only"
out=$(run_container nvim --headless +'lua local lines = vim.g.clipboard.paste["+"](); print(#lines[1], lines[2])' +qa 2>&1)
assert_contains "$out" "0"
assert_contains "$out" "v"
pass "OSC 52 fallback does not query terminal paste"

# Test 3: host relay clipboard provider activates when relay socket is mounted
if command -v socat >/dev/null 2>&1; then
  sock="/tmp/workenv-clipboard-test.sock"
  clip="/tmp/workenv-clipboard-test.txt"
  rm -f "$sock" "$clip"
  WORKENV_RELAY_SOCK="$sock" \
  WORKENV_RELAY_CLIPBOARD_SET="tee $clip" \
  WORKENV_RELAY_CLIPBOARD_GET="cat $clip" \
    bash "$(dirname "$0")/../bin/workenv-relay.sh" &
  relay_pid=$!
  trap 'kill "$relay_pid" 2>/dev/null || true; rm -f "$sock" "$clip"' EXIT
  for _ in $(seq 1 50); do [[ -S "$sock" ]] && break; sleep 0.1; done

  out=$(docker run --rm \
    -v "$TEST_VOLUME":/home/dev/.local/share/workenv-root \
    -v "$sock":/run/host-relay/open.sock \
    "$IMAGE" nvim --headless \
      +'lua vim.fn.setreg("+", "relay clipboard ok"); print((vim.g.clipboard or {}).name or "none")' \
      +'lua print(vim.fn.getreg("+"))' \
      +qa 2>&1)
  assert_contains "$out" "workenv host relay"
  assert_contains "$out" "relay clipboard ok"
  assert_contains "$(cat "$clip")" "relay clipboard ok"
  pass "host relay clipboard copy/paste works"
else
  echo "SKIP: host relay clipboard test (socat not installed on host)"
fi

# Test 4: tmux passthrough enabled
out=$(run_container grep -E 'allow-passthrough' /opt/workenv-defaults/tmux/tmux.conf)
assert_contains "$out" "on"
pass "tmux allow-passthrough on"
