#!/usr/bin/env bash
# Static lint step. Mechanically enforces the project rules catalogued in
# .agentos/{positive,negative}-rules.md and .agentos/enforcement.md.
# No Docker image required — this runs against the host source tree.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

cd "$REPO_ROOT"

fail_count=0
note_fail() { echo "LINT FAIL: $1"; fail_count=$((fail_count + 1)); }

# Collect the shell scripts we govern.
shell_files=(
  bin/workenv bin/workenv-relay.sh
  bin/shellc bin/tmuxc bin/nvimc bin/workenv-stop bin/workenv-clean
  libexec/_workenv-lib.sh libexec/entrypoint.sh
  share/shims/xdg-open share/shims/notify-send share/shims/nvim
  install.sh uninstall.sh
  tests/lib.sh tests/run_all.sh
)
while IFS= read -r f; do shell_files+=("$f"); done < <(ls tests/step*.sh)

# 1. POS-100 / NEG-104: every shell script uses 'set -euo pipefail', never bare 'set -eu'.
if hits=$(grep -RlE '^set -eu *$' "${shell_files[@]}" 2>/dev/null); then
  note_fail "bare 'set -eu' (need 'set -euo pipefail') in: $(echo "$hits" | tr '\n' ' ')"
else
  pass "all shell scripts use 'set -euo pipefail'"
fi

# 2. bash -n syntax check.
syntax_ok=true
for f in "${shell_files[@]}"; do
  bash -n "$f" 2>/dev/null || { note_fail "bash -n: $f"; syntax_ok=false; }
done
$syntax_ok && pass "bash -n clean across all shell scripts"

# 3. luac -p syntax check over every Lua file.
if find config -name '*.lua' -print0 | xargs -0 -n1 luac -p >/dev/null 2>&1; then
  pass "luac -p clean across all Lua files"
else
  note_fail "luac -p reported a Lua syntax error (run: find config -name '*.lua' -print0 | xargs -0 -n1 luac -p)"
fi

# 4. POS-101 / NEG-101: no ':latest' in a Dockerfile dependency context.
# The only sanctioned 'workenv:latest' is the *output* tag, which never appears in the Dockerfile.
if grep -nE ':latest' Dockerfile >/dev/null 2>&1; then
  note_fail "Dockerfile references ':latest' — pin via an ARG instead"
else
  pass "no ':latest' tags in Dockerfile"
fi

# 5. NEG-102: legacy shims stay one-line 'exec' wrappers.
shims_ok=true
for s in shellc tmuxc nvimc workenv-stop workenv-clean; do
  lines=$(wc -l < "bin/$s")
  last=$(grep -vE '^[[:space:]]*(#|$)' "bin/$s" | tail -1)
  if (( lines > 25 )) || [[ ! "$last" =~ ^exec\ \"\$SCRIPT_DIR/workenv\"\ [a-z]+\ \"\$@\"$ ]]; then
    note_fail "legacy shim bin/$s has logic (lines=$lines, last='$last')"
    shims_ok=false
  fi
done
$shims_ok && pass "legacy shims are one-line exec wrappers"

# 6. POS-102 / NEG-103: WORKENV_RUN_* arrays are mutated only inside the two
# helper functions in the lib, and never in bin/workenv.
lib_violations=$(awk '
  /^workenv_add_mount\(\) \{/   { inhelper = 1 }
  /^workenv_add_env_arg\(\) \{/ { inhelper = 1 }
  inhelper && /^\}/             { inhelper = 0; next }
  !inhelper && /WORKENV_RUN_(MOUNTS|ENVS|MOUNT_SPECS|ENV_SPECS)\+=/ { print FILENAME ":" NR ": " $0 }
' libexec/_workenv-lib.sh)
bin_violations=$(grep -nE 'WORKENV_RUN_(MOUNTS|ENVS|MOUNT_SPECS|ENV_SPECS)\+=' bin/workenv 2>/dev/null || true)
if [[ -n "$lib_violations$bin_violations" ]]; then
  note_fail "WORKENV_RUN_* mutated outside workenv_add_mount/workenv_add_env_arg: ${lib_violations}${bin_violations}"
else
  pass "WORKENV_RUN_* arrays mutated only via the add helpers"
fi

# 7. NEG-104: no '${arr[@]:-}' iteration idiom in the launcher/relay code (it
# poisons empty-array expansion). Scoped to executable code under bin/libexec/
# share/shims — test files legitimately mention the anti-pattern in comments.
# The '[@]' before ':-' makes this match arrays only, not scalar '${var:-}'.
if grep -RnE '\$\{[A-Za-z_][A-Za-z0-9_]*\[@\]:-\}' bin libexec share/shims >/dev/null 2>&1; then
  note_fail "found '\${arr[@]:-}' — use '\"\${arr[@]+\"\${arr[@]}\"}\"' instead: $(grep -RlnE '\$\{[A-Za-z_][A-Za-z0-9_]*\[@\]:-\}' bin libexec share/shims | tr '\n' ' ')"
else
  pass "no fragile \${arr[@]:-} expansions in launcher/relay code"
fi

# 8. POS-106: no cross-file plugin requires under lua/plugins/.
if grep -RnE 'require\("plugins\.' config/nvim/lua/plugins/ >/dev/null 2>&1; then
  note_fail "cross-file plugin require under lua/plugins/: $(grep -RlnE 'require\("plugins\.' config/nvim/lua/plugins/ | tr '\n' ' ')"
else
  pass "no cross-file plugin requires"
fi

# 9. NEG-106: nothing deletes the shared workenv-root volume (the test volume is fine).
if grep -RnE 'volume[[:space:]]+rm[^[:space:]]*[[:space:]]+("?)workenv-root\1' bin libexec share >/dev/null 2>&1; then
  note_fail "found a 'docker volume rm workenv-root' — forbidden (destroys all user state)"
else
  pass "no deletion of the workenv-root volume"
fi

# 10. POS-107 (lightweight): the relay forwards via argv, not shell interpolation.
# Catch the specific regression — osascript with an interpolated -e string.
if grep -nE 'osascript -e .*\$(1|\{?msg)' bin/workenv-relay.sh >/dev/null 2>&1; then
  note_fail "relay osascript interpolates the message into the -e string (use 'on run argv')"
else
  pass "relay notify path does not interpolate into a shell/osascript string"
fi

# 11. Layering: host-integration core must NOT live in the swappable nvim config
# dir — it belongs in share/nvim-core/ (baked, always-on). Regression guard for
# the kernel/userland split.
if [[ -e config/nvim/lua/config/clipboard.lua || -e config/nvim/lua/config/ui-open.lua ]]; then
  note_fail "host integration (clipboard/ui-open) must live in share/nvim-core/, not config/nvim/lua/config/"
else
  pass "host-integration core stays out of the swappable nvim config dir"
fi

# 12. The nvim core plugins must be self-contained (no require of the userland
# 'config.'/'util.' tree — they load under foreign configs too).
if grep -RnE "require\(['\"](config|util)\." share/nvim-core/ >/dev/null 2>&1; then
  note_fail "share/nvim-core must not require the userland config/util tree: $(grep -RlnE "require\(['\"](config|util)\." share/nvim-core/ | tr '\n' ' ')"
else
  pass "nvim core is self-contained (no userland requires)"
fi

# 13. Single source of truth: LSP/formatter/linter consumers derive from
# config.tools rather than carrying their own hand-synced lists.
tools_consumers=(
  config/nvim/lua/config/lsp.lua
  config/nvim/lua/plugins/mason.lua
  config/nvim/lua/plugins/conform.lua
  config/nvim/lua/plugins/nvim-lint.lua
)
tools_missing=""
for f in "${tools_consumers[@]}"; do
  grep -q 'require("config.tools")' "$f" || tools_missing="$tools_missing $f"
done
if [[ -n "$tools_missing" ]]; then
  note_fail "these must derive tool lists from config.tools:$tools_missing"
else
  pass "LSP/formatter/linter lists derive from config.tools (single source)"
fi

if (( fail_count > 0 )); then
  fail "step18 static lint: $fail_count check(s) failed"
fi
echo "PASS: step18 static lint — all checks green"
