#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

build_image

# Test 1: conform loads
out=$(run_container nvim --headless +'lua vim.pack.add({{src="https://github.com/stevearc/conform.nvim"}}, {load=true}); print(pcall(require, "conform"))' +qa 2>&1)
assert_contains "$out" "true"
pass "conform installs and loads"

# Test 2: nvim-lint loads
out=$(run_container nvim --headless +'lua vim.pack.add({{src="https://github.com/mfussenegger/nvim-lint"}}, {load=true}); print(pcall(require, "lint"))' +qa 2>&1)
assert_contains "$out" "true"
pass "nvim-lint installs and loads"

# Test 3: mason-tool-installer spec registered (repo cloned by util.pack)
# Warm-up: run nvim with a wait so mason-tool-installer.nvim clone completes
run_container nvim --headless \
  +'lua vim.wait(10000, function() return vim.uv.fs_stat("/home/dev/.local/share/workenv-root/data/nvim/site/pack/core/opt/mason-tool-installer.nvim") ~= nil end)' \
  +qa >/dev/null 2>&1 || true
out=$(run_container find /home/dev/.local/share/workenv-root/data/nvim -maxdepth 6 -type d -name "mason-tool-installer.nvim" 2>&1 || true)
assert_contains "$out" "mason-tool-installer.nvim"
pass "mason-tool-installer spec cloned"
