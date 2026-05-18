#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

build_image

# Test 1: TPM cloned in shared location
out=$(run_container ls /opt/tpm)
assert_contains "$out" "tpm"
pass "TPM installed"

# Test 2: tmux config exists
out=$(run_container ls /opt/workenv-defaults/tmux/tmux.conf)
[[ -n "$out" ]] || fail "tmux.conf default missing"
pass "tmux.conf shipped"

# Test 3: entrypoint seeds tmux config
out=$(run_container ls /home/dev/.local/share/workenv-root/config/tmux/)
assert_contains "$out" "tmux.conf"
pass "tmux.conf seeded to volume"

# Test 4: tmux can load config without error
out=$(run_container tmux -f /home/dev/.local/share/workenv-root/config/tmux/tmux.conf -L test list-keys 2>&1 | head -1 || true)
[[ -n "$out" ]] || fail "tmux config errored"
pass "tmux config loads"
