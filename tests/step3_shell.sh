#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

build_image

# Test 1: oh-my-zsh installed at /opt/oh-my-zsh (shared location, read-only)
out=$(run_container ls /opt/oh-my-zsh)
assert_contains "$out" "oh-my-zsh.sh"
pass "oh-my-zsh installed"

# Test 2: required zsh plugins cloned
for plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-vi-mode; do
  out=$(run_container ls "/opt/oh-my-zsh/custom/plugins/$plugin")
  [[ -n "$out" ]] || fail "$plugin not installed"
  pass "$plugin installed"
done

# Test 3: ZDOTDIR is set to shipped zsh config
out=$(run_container sh -c 'echo $ZDOTDIR')
assert_contains "$out" "/config/zsh"
pass "ZDOTDIR exported"

# Test 4: interactive zsh loads without error
out=$(run_container zsh -ic 'echo READY' 2>&1)
assert_contains "$out" "READY"
pass "zsh interactive load succeeds"

# Test 5: aliases loaded
out=$(run_container zsh -ic 'alias vi' 2>&1)
assert_contains "$out" "nvim"
pass "vi alias present"

# Test 6: ZSH_CUSTOM points to writable user location
out=$(run_container zsh -ic 'echo $ZSH_CUSTOM' 2>&1)
assert_contains "$out" "/config/zsh/custom"
pass "ZSH_CUSTOM points to writable user location"
