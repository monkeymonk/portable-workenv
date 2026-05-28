#!/usr/bin/env bash
# Bring-your-own-config: a user's own nvim config (mounted over the volume's
# config/nvim) must still get the baked host-integration core — clipboard relay
# + gx/open routing — because core lives in the image on packpath, outside the
# swappable config dir. See share/nvim-core/ + share/shims/nvim.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

build_image

BYO="$(mktemp -d)"
trap 'rm -rf "$BYO"' EXIT
mkdir -p "$BYO/nvim"
# A minimal foreign config that does NOT set vim.g.clipboard — so if the
# clipboard provider is present, it can only have come from core.
cat > "$BYO/nvim/init.lua" <<'EOF'
vim.g.byo_marker = true
EOF

# Test 1: under a foreign config + no relay, core still loads (OSC52 fallback).
out=$(docker run --rm \
  -v "$TEST_VOLUME":/home/dev/.local/share/workenv-root \
  -v "$BYO/nvim":/home/dev/.local/share/workenv-root/config/nvim:ro \
  "$IMAGE" nvim --headless \
    +'lua print("byo="..tostring(vim.g.byo_marker).." clip="..((vim.g.clipboard or {}).name or "none"))' \
    +qa 2>&1)
assert_contains "$out" "byo=true"
assert_contains "$out" "OSC 52"
pass "core integration loads under a bring-your-own nvim config"

# Test 2: with the relay socket mounted, the foreign config gets host-relay clipboard.
if command -v socat >/dev/null 2>&1; then
  sock="$(mktemp -u -p /tmp workenv-byo-test.XXXXXX.sock)"
  clip="$(mktemp -u -p /tmp workenv-byo-test.XXXXXX.txt)"
  WORKENV_RELAY_SOCK="$sock" \
  WORKENV_RELAY_CLIPBOARD_SET="tee $clip" \
  WORKENV_RELAY_CLIPBOARD_GET="cat $clip" \
    bash "$(dirname "$0")/../bin/workenv-relay.sh" &
  relay_pid=$!
  trap 'kill "$relay_pid" 2>/dev/null || true; rm -rf "$BYO" "$sock" "$clip"' EXIT
  for _ in $(seq 1 50); do [[ -S "$sock" ]] && break; sleep 0.1; done

  out=$(docker run --rm \
    -v "$TEST_VOLUME":/home/dev/.local/share/workenv-root \
    -v "$BYO/nvim":/home/dev/.local/share/workenv-root/config/nvim:ro \
    -v "$sock":/run/host-relay/open.sock \
    "$IMAGE" nvim --headless \
      +'lua print("byo="..tostring(vim.g.byo_marker).." clip="..((vim.g.clipboard or {}).name or "none"))' \
      +qa 2>&1)
  assert_contains "$out" "byo=true"
  assert_contains "$out" "workenv host relay"
  pass "host-relay clipboard works under a bring-your-own nvim config"
else
  echo "SKIP: relay-under-BYO test (socat not installed on host)"
fi

# Test 3: WORKENV_NVIM_NO_CORE=1 disables the packpath injection (escape hatch).
out=$(docker run --rm \
  -v "$TEST_VOLUME":/home/dev/.local/share/workenv-root \
  -v "$BYO/nvim":/home/dev/.local/share/workenv-root/config/nvim:ro \
  -e WORKENV_NVIM_NO_CORE=1 \
  "$IMAGE" nvim --headless \
    +'lua print("clip="..((vim.g.clipboard or {}).name or "none"))' \
    +qa 2>&1)
assert_contains "$out" "clip=none"
pass "WORKENV_NVIM_NO_CORE=1 opts out of core injection"
