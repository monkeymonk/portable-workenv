#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

build_image
cleanup_test_volume

# Warm-up: first run on a fresh volume clones plugins via vim.pack.add and
# prints install progress. Run once discarded so Test 1's no-output assertion
# measures steady state, not first-boot install noise.
run_container nvim --headless +qa >/dev/null 2>&1 || true

# Test 1: nvim starts headless with no error output
out=$(run_container nvim --headless +qa 2>&1)
[[ -z "$out" ]] || fail "nvim produced output: $out"
pass "nvim starts cleanly"

# Test 2: nvim resolves config from the volume's $XDG_CONFIG_HOME/nvim
out=$(run_container nvim --headless +'lua print(vim.fn.stdpath("config"))' +qa 2>&1)
assert_contains "$out" "/workenv-root/config/nvim"
pass "nvim config path resolves to volume config/nvim"

# Test 3: options loaded — leader is space
out=$(run_container nvim --headless +'lua print(vim.g.mapleader)' +qa 2>&1)
assert_contains "$out" " "
pass "leader set to space"

# Test 4: grepprg set to rg
out=$(run_container nvim --headless +'lua print(vim.o.grepprg)' +qa 2>&1)
assert_contains "$out" "rg"
pass "grepprg=rg"

# Test 5: util.map module loads
out=$(run_container nvim --headless +'lua require("util.map"); print("ok")' +qa 2>&1)
assert_contains "$out" "ok"
pass "util.map loads"

# Test 6: pack loader module works
out=$(run_container nvim --headless +'lua local pack = require("util.pack"); pack.add({}); print("ok")' +qa 2>&1)
assert_contains "$out" "ok"
pass "util.pack.add() works with empty list"

# Test 7: pack spec normalization
out=$(run_container nvim --headless +'lua local s = require("util.pack.spec").normalize({"catppuccin/nvim", name="catppuccin"}); print(s.src, s.name)' +qa 2>&1)
assert_contains "$out" "https://github.com/catppuccin/nvim"
assert_contains "$out" "catppuccin"
pass "spec.normalize handles github shorthand"

# Test 8: catppuccin colorscheme applied
out=$(run_container nvim --headless +'lua print(vim.g.colors_name)' +qa 2>&1)
assert_contains "$out" "catppuccin"
pass "catppuccin colorscheme active"

# Test 9: lualine loaded
out=$(run_container nvim --headless +'lua print(pcall(require, "lualine"))' +qa 2>&1)
assert_contains "$out" "true"
pass "lualine module loadable"

# Test 10: laststatus is 3 (global statusline)
out=$(run_container nvim --headless +'lua print(vim.o.laststatus)' +qa 2>&1)
assert_contains "$out" "3"
pass "global statusline enabled"

# Test 11: snacks loaded
out=$(run_container nvim --headless +'lua print(pcall(require, "snacks"))' +qa 2>&1)
assert_contains "$out" "true"
pass "snacks module loadable"

# Test 12: snacks picker function callable
out=$(run_container nvim --headless +'lua print(type(require("snacks").picker.files))' +qa 2>&1)
assert_contains "$out" "function"
pass "snacks.picker.files is a function"

# Test 13: dependency-backed eager plugins load cleanly
out=$(run_container nvim --headless +'lua print(pcall(require, "nui.object"), pcall(require, "noice"))' +qa 2>&1)
assert_contains "$out" "true"
[[ "$out" != *"false"* ]] || fail "noice/nui dependency chain failed: $out"
pass "noice loads with nui dependency"

# Test 14: startup did not hide errors in Neovim state logs
out=$(run_container sh -c '
  for log in "$XDG_STATE_HOME"/nvim/*.log; do
    [ -f "$log" ] || continue
    grep -Ei "module .* not found|stack traceback|pack: config .* failed|^ERR| error:" "$log" || true
  done
' 2>&1)
[[ -z "$out" ]] || fail "nvim wrote startup errors to state logs: $out"
pass "nvim state logs contain no startup errors"

# Test 15: Mason Tool Installer can be required after normal startup
out=$(run_container nvim --headless +'lua print(pcall(require, "mason-tool-installer"))' +qa 2>&1)
assert_contains "$out" "true"
[[ "$out" != *"loop or previous error loading module"* ]] || fail "mason-tool-installer VimEnter hook failed: $out"
pass "mason-tool-installer survives startup"

# Test 16: Snacks dashboard does not assume Lazy.nvim
out=$(run_container nvim --headless +'lua local ok, err = pcall(function() require("snacks").dashboard() end); print(ok, err or "")' +qa 2>&1)
assert_contains "$out" "true"
[[ "$out" != *"lazy.stats"* ]] || fail "snacks dashboard tried to load lazy.stats: $out"
pass "snacks dashboard works without lazy.nvim"
