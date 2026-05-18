#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

build_image

# Test 1: mise installed
out=$(run_container mise --version 2>&1 || true)
[[ -n "$out" ]] || fail "mise not installed"
pass "mise installed"

# Test 2: Node LTS baked in and on PATH
out=$(run_container zsh -ic 'node --version')
assert_contains "$out" "v"
pass "node available"

# Test 3: npm available
out=$(run_container zsh -ic 'npm --version')
[[ -n "$out" ]] || fail "npm not available"
pass "npm available"

# Warm-up for fresh volumes: install mason on first run
run_container nvim --headless +qa >/dev/null 2>&1 || true

# Test 4: mason loads
out=$(run_container nvim --headless +'lua print(pcall(require, "mason"))' +qa 2>&1)
assert_contains "$out" "true"
pass "mason loads"

# Test 5: mason install path under workenv data
out=$(run_container nvim --headless +'lua print(require("mason.settings").current.install_root_dir)' +qa 2>&1)
assert_contains "$out" "/workenv-root/data/nvim/mason"
pass "mason install path under workenv data"

# Test 6: blink.cmp loads
out=$(run_container nvim --headless +'lua print(pcall(require, "blink.cmp"))' +qa 2>&1)
assert_contains "$out" "true"
pass "blink.cmp loads"

# Test 7: lspsaga, lsp_lines, noice specs are registered (pack repos cloned)
out=$(run_container find /home/dev/.local/share/workenv-root/data/nvim -maxdepth 6 -type d \( -name "lspsaga.nvim" -o -name "lsp_lines.nvim" -o -name "noice.nvim" \) 2>&1 || true)
assert_contains "$out" "lspsaga.nvim"
assert_contains "$out" "lsp_lines.nvim"
assert_contains "$out" "noice.nvim"
pass "lspsaga/lsp_lines/noice specs cloned to pack dir"
