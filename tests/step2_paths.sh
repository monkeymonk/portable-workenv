#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

build_image
cleanup_test_volume

# Test 1: entrypoint creates directory structure
out=$(run_container ls /home/dev/.local/share/workenv-root)
for dir in config data state cache; do
  assert_contains "$out" "$dir"
done
pass "workspace root subdirs created"

# Test 2: all XDG subdirs exist
out=$(run_container ls /home/dev/.local/share/workenv-root/config)
for sub in nvim tmux zsh mise; do
  assert_contains "$out" "$sub"
done
pass "config subdirs created"

# Test 3: XDG env vars set
for var in XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME MISE_DATA_DIR; do
  out=$(run_container sh -c "echo \$$var")
  [[ -n "$out" ]] || fail "$var is empty"
done
pass "all env vars exported"

# Test 4: a file written in one run persists to the next
run_container sh -c 'echo hello > /home/dev/.local/share/workenv-root/state/zsh/marker.txt'
out=$(run_container cat /home/dev/.local/share/workenv-root/state/zsh/marker.txt)
assert_contains "$out" "hello"
pass "state persists across runs"

# Test 5: PATH includes mise shims and Mason bin in correct order
out=$(run_container sh -c 'echo "$PATH"')
# mise shims must come before /usr/bin
shims="/home/dev/.local/share/workenv-root/data/mise/shims"
mason="/home/dev/.local/share/workenv-root/data/nvim/mason/bin"
local_bin="/home/dev/.local/bin"

# Verify all expected segments present
assert_contains "$out" "$shims"
assert_contains "$out" "$mason"
assert_contains "$out" "$local_bin"
pass "PATH contains mise shims, mason, local bin"

# Verify order: mise shims before mason before local bin before /usr/bin
shims_idx=$(awk -v s="$shims" 'BEGIN{ print index(ARGV[1], s) }' "$out")
mason_idx=$(awk -v s="$mason" 'BEGIN{ print index(ARGV[1], s) }' "$out")
local_idx=$(awk -v s="$local_bin" 'BEGIN{ print index(ARGV[1], s) }' "$out")
usr_idx=$(awk -v s="/usr/bin" 'BEGIN{ print index(ARGV[1], s) }' "$out")

for idx in "$shims_idx" "$mason_idx" "$local_idx" "$usr_idx"; do
  [[ "$idx" -gt 0 ]] || fail "PATH index lookup returned 0 (segment missing or awk issue)"
done

[[ "$shims_idx" -lt "$mason_idx" ]] || fail "mise shims not before mason"
[[ "$mason_idx" -lt "$local_idx" ]] || fail "mason not before local bin"
[[ "$local_idx" -lt "$usr_idx" ]] || fail "local bin not before /usr/bin"
pass "PATH precedence correct"

cleanup_test_volume
