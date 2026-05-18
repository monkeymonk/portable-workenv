#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

build_image

# Test 1: gitsigns installs and loads
out=$(run_container nvim --headless +'lua vim.pack.add({{src="https://github.com/lewis6991/gitsigns.nvim"}}, {load=true}); print(pcall(require, "gitsigns"))' +qa 2>&1)
assert_contains "$out" "true"
pass "gitsigns loads"

# Test 2: neogit installs and loads (eager via pack spec test)
out=$(run_container nvim --headless +'lua vim.pack.add({{src="https://github.com/NeogitOrg/neogit"},{src="https://github.com/sindrets/diffview.nvim"},{src="https://github.com/nvim-lua/plenary.nvim"}}, {load=true}); print(pcall(require, "neogit"))' +qa 2>&1)
assert_contains "$out" "true"
pass "neogit loads"
