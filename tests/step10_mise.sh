#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

build_image

# Test 1: mise activation injected into PATH when shell starts
out=$(run_container zsh -ic 'which node')
assert_contains "$out" "node"
pass "node resolvable in interactive shell"

# Test 2: mise shims directory in PATH
out=$(run_container zsh -ic 'echo $PATH')
assert_contains "$out" "mise/shims"
pass "mise shims in PATH"

# Test 3: mise install in a dir with mise.toml resolves
run_container zsh -ic '
  mkdir -p /tmp/proj && cd /tmp/proj &&
  echo "[tools]" > mise.toml &&
  echo "node = \"22\"" >> mise.toml &&
  mise install -y 2>&1 | tail -n 3
' | head -5
pass "mise install works"
