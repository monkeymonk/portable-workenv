#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

build_image

# Test 1: tree-sitter CLI installed
out=$(run_container tree-sitter --version)
assert_contains "$out" "tree-sitter"
pass "tree-sitter CLI installed"

# Test 2: nvim-treesitter module loads
out=$(run_container nvim --headless +'lua print(pcall(require, "nvim-treesitter"))' +qa 2>&1)
assert_contains "$out" "true"
pass "nvim-treesitter loads"

# Test 3: baseline parsers install (this will take time on first run)
# We force sync install by running a buffer of a given ft
out=$(run_container sh -c 'nvim --headless +"TSInstallSync! lua" +qa 2>&1' || true)
# Verify parser directory has lua.so
out=$(run_container find /home/dev/.local/share/workenv-root/data/nvim -name "lua.so" 2>&1 || true)
assert_contains "$out" "lua.so"
pass "lua parser installed to shared volume"

# Test 4: treesitter highlight active on a lua file
out=$(run_container sh -c 'echo "local x = 1" > /tmp/t.lua && nvim --headless -u "$XDG_CONFIG_HOME/nvim/init.lua" /tmp/t.lua +"lua vim.wait(2000, function() return vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil end); print(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil and \"HIGHLIGHT_ON\" or \"HIGHLIGHT_OFF\")" +qa' 2>&1 || true)
assert_contains "$out" "HIGHLIGHT_ON"
pass "treesitter highlight active on .lua"
