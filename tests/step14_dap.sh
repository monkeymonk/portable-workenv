#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

build_image

# Test 1: dap spec shipped
run_container ls /opt/workenv-defaults/nvim/lua/plugins/dap.lua >/dev/null
pass "dap spec shipped"

# Test 2: mason-nvim-dap is listed as a dependency in the spec
out=$(run_container cat /opt/workenv-defaults/nvim/lua/plugins/dap.lua)
assert_contains "$out" "mason-nvim-dap"
pass "mason-nvim-dap referenced"

# Test 3: require("dap") loads when forced (cmd trigger)
out=$(run_container nvim --headless +'DapShowLog' +qa 2>&1 || true)
# DapShowLog is only registered after plugin loads; if it loads we won't see "Not an editor command"
if echo "$out" | grep -q "Not an editor command"; then
  fail "Dap commands not registered"
fi
pass "Dap commands registered after load"
