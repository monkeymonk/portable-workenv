#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

HAS_SOCAT=false
command -v socat >/dev/null 2>&1 && HAS_SOCAT=true

# Per-run unique paths so concurrent test invocations don't collide on /tmp.
HOST_SOCK="$(mktemp -u -p /tmp workenv-relay-test.XXXXXX.sock)"
STUB_LOG="$(mktemp -u -p /tmp workenv-relay-test.XXXXXX.log)"
STUB_BIN="$(mktemp -p /tmp workenv-relay-stub.XXXXXX)"
HOST_SOCK_E2E="$(mktemp -u -p /tmp workenv-relay-test-e2e.XXXXXX.sock)"
STUB_LOG_E2E="$(mktemp -u -p /tmp workenv-relay-test-e2e.XXXXXX.log)"
STUB_BIN_E2E="$(mktemp -p /tmp workenv-relay-stub-e2e.XXXXXX)"

# The stub captures the argv it receives. The previous test used `tee -a $LOG`
# but tee interprets the URL as a second output file, so nothing was ever
# written to $LOG — the assertions silently no-op'd. This script writes each
# invocation's first argument as a line in $LOG.
write_stub() {
  local bin="$1" log="$2"
  cat > "$bin" <<EOF
#!/usr/bin/env bash
printf '%s\\n' "\$1" >> "$log"
EOF
  chmod +x "$bin"
}
write_stub "$STUB_BIN" "$STUB_LOG"
write_stub "$STUB_BIN_E2E" "$STUB_LOG_E2E"

cleanup() {
  kill $(jobs -p) 2>/dev/null || true
  rm -f "$HOST_SOCK" "$STUB_LOG" "$STUB_BIN" \
        "$HOST_SOCK_E2E" "$STUB_LOG_E2E" "$STUB_BIN_E2E" 2>/dev/null || true
}
trap cleanup EXIT

if [[ "$HAS_SOCAT" == "true" ]]; then
  # Host-side test: daemon accepts "open URL\n" and dispatches to a stub.
  rm -f "$HOST_SOCK"
  : > "$STUB_LOG"
  WORKENV_RELAY_SOCK="$HOST_SOCK" \
  WORKENV_RELAY_OPENER="$STUB_BIN" \
  WORKENV_RELAY_NOTIFIER="$STUB_BIN" \
    bash "$(dirname "$0")/../bin/workenv-relay.sh" &
  sleep 0.5

  printf 'open https://example.com\n' | socat - UNIX-CONNECT:"$HOST_SOCK"
  sleep 0.2
  grep -q 'https://example.com' "$STUB_LOG" || fail "relay did not dispatch open"
  pass "relay dispatched open"

  : > "$STUB_LOG"
  printf 'notify hello\n' | socat - UNIX-CONNECT:"$HOST_SOCK"
  sleep 0.2
  grep -q '^hello$' "$STUB_LOG" || fail "relay did not dispatch notify"
  pass "relay dispatched notify"

  # URL scheme allowlist: file:// and javascript: must be rejected.
  : > "$STUB_LOG"
  printf 'open file:///etc/passwd\n' | socat - UNIX-CONNECT:"$HOST_SOCK"
  sleep 0.2
  if grep -q 'file:///etc/passwd' "$STUB_LOG"; then
    fail "relay forwarded file:// URL — allowlist bypassed"
  fi
  pass "relay rejected file:// URL"

  : > "$STUB_LOG"
  printf 'open javascript:alert(1)\n' | socat - UNIX-CONNECT:"$HOST_SOCK"
  sleep 0.2
  if grep -q 'javascript:' "$STUB_LOG"; then
    fail "relay forwarded javascript: URL"
  fi
  pass "relay rejected javascript: URL"

  # The notify path must pass the message as a single argv element. A literal
  # message containing `";say injected` must land in the log verbatim — never
  # be interpreted by a shell.
  : > "$STUB_LOG"
  printf 'notify "evil";say injected\n' | socat - UNIX-CONNECT:"$HOST_SOCK"
  sleep 0.2
  if ! grep -qF '"evil";say injected' "$STUB_LOG"; then
    fail "relay notify did not pass the literal message"
  fi
  # A separate "say injected" line would indicate shell interpretation.
  if grep -qx 'injected' "$STUB_LOG"; then
    fail "relay notify path is shell-interpreting argv"
  fi
  pass "relay notify passes message as argv (no shell injection)"
else
  echo "SKIP: relay daemon tests (socat not installed on host)"
fi

# Container ships both shims under /usr/local/bin.
build_image
for s in xdg-open notify-send; do
  out=$(docker run --rm "$IMAGE" ls /usr/local/bin/$s)
  [[ -n "$out" ]] || fail "$s shim missing"
done
pass "shims present in image"

# Shims print a warning and exit 0 when socket absent.
out=$(docker run --rm "$IMAGE" xdg-open https://example.com 2>&1)
assert_contains "$out" "relay socket"
pass "xdg-open shim degrades gracefully"

if [[ "$HAS_SOCAT" == "true" ]]; then
  # Shim sends via socket when mounted.
  rm -f "$HOST_SOCK_E2E"
  : > "$STUB_LOG_E2E"
  WORKENV_RELAY_SOCK="$HOST_SOCK_E2E" \
  WORKENV_RELAY_OPENER="$STUB_BIN_E2E" \
    bash "$(dirname "$0")/../bin/workenv-relay.sh" &
  sleep 0.5

  docker run --rm \
    -v "$HOST_SOCK_E2E":/run/host-relay/open.sock \
    "$IMAGE" xdg-open https://e2e.example >/dev/null
  sleep 0.2
  grep -q 'https://e2e.example' "$STUB_LOG_E2E" \
    || fail "shim → host relay → opener did not log URL"
  pass "shim → host relay → opener works end-to-end"

  kill %2 2>/dev/null || true
else
  echo "SKIP: e2e relay test (socat not installed on host)"
fi
