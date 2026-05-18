#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

build_image

# Test 1: image runs as `dev` user
out=$(run_container whoami)
assert_contains "$out" "dev"
pass "container runs as dev user"

# Test 2: UID matches host (Linux/WSL)
host_uid=$(id -u)
out=$(run_container id -u)
assert_contains "$out" "$host_uid"
pass "container UID matches host"

# Test 3: home directory exists and is owned by dev
out=$(run_container ls -ld /home/dev)
assert_contains "$out" "dev dev"
pass "home directory ownership correct"

# Test 4: zsh is installed and runnable for dev user
out=$(run_container zsh -c 'echo $ZSH_VERSION')
[[ -n "$out" ]] || fail "zsh not runnable"
pass "zsh installed and runnable"

# Test 5: core tools present
for tool in git curl wget jq tree ssh socat tmux; do
  out=$(run_container which "$tool") || fail "$tool missing"
  pass "$tool available"
done

# Test 6: git-lfs available
out=$(run_container git lfs version)
assert_contains "$out" "git-lfs"
pass "git-lfs available"

# Test 7: python available
out=$(run_container python3 --version)
assert_contains "$out" "Python 3"
pass "python3 available"

# Test 8: build tools available
out=$(run_container gcc --version)
assert_contains "$out" "gcc"
pass "build-essential available"

out=$(run_container cmake --version)
assert_contains "$out" "cmake"
pass "cmake available"

# Test 9: modern binaries installed with expected versions
out=$(run_container rg --version)
assert_contains "$out" "ripgrep"
pass "ripgrep installed"

out=$(run_container fd --version)
assert_contains "$out" "fd"
pass "fd installed"

out=$(run_container fzf --version)
# fzf outputs just version number
[[ -n "$out" ]] || fail "fzf empty output"
pass "fzf installed"

out=$(run_container bat --version)
assert_contains "$out" "bat"
pass "bat installed"

out=$(run_container delta --version)
assert_contains "$out" "delta"
pass "delta installed"

out=$(run_container zoxide --version)
assert_contains "$out" "zoxide"
pass "zoxide installed"

out=$(run_container chafa --version)
assert_contains "$out" "Chafa"
pass "chafa installed"

# Test 10: Neovim 0.12.x
out=$(run_container nvim --version | head -n1)
assert_contains "$out" "NVIM v0.12"
pass "Neovim 0.12.x installed"

# Warm-up: first run on a fresh volume installs plugins — discard that output
run_container nvim --headless +qa >/dev/null 2>&1 || true

# Test 11: Neovim starts headless without error (steady state)
out=$(run_container nvim --headless +qa 2>&1)
[[ -z "$out" ]] || fail "nvim produced output: $out"
pass "Neovim starts headless cleanly"

# Test 12: entrypoint sets WORKENV_ROOT
out=$(run_container sh -c 'echo "$WORKENV_ROOT"')
assert_contains "$out" "/home/dev/.local/share/workenv-root"
pass "WORKENV_ROOT exported"
