#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

build_image

# Test 1: render-markdown spec file present in defaults
run_container ls /opt/workenv-defaults/nvim/lua/plugins/render-markdown.lua >/dev/null
pass "render-markdown spec shipped"

# Test 2: plugin loads on markdown ft (headless open .md file).
# The FileType autocmd fires synchronously when the .md file is loaded, so the
# subsequent +lua command can `require` the plugin without a defer. (An older
# version of this test used vim.defer_fn, which never fires in headless mode —
# nvim exits as soon as +cmd processing completes.)
out=$(run_container bash -c '
  mkdir -p /tmp/md && echo "# hello" > /tmp/md/test.md
  nvim --headless /tmp/md/test.md +"lua print(pcall(require, [[render-markdown]]))" +"qa!" 2>&1
')
assert_contains "$out" "true"
pass "render-markdown loads on markdown ft"

# Test 3: markdown-plus spec present
run_container ls /opt/workenv-defaults/nvim/lua/plugins/markdown-plus.lua >/dev/null
pass "markdown-plus spec shipped"
