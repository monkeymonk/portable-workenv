#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

HAS_SOCAT=false
command -v socat >/dev/null 2>&1 && HAS_SOCAT=true

cleanup() {
  kill $(jobs -p) 2>/dev/null || true
  rm -rf /tmp/workenv-relay-test.sock /tmp/workenv-relay-test.log \
         /tmp/workenv-relay-test-e2e.sock /tmp/workenv-relay-test-e2e.log 2>/dev/null || true
}
trap cleanup EXIT

if [[ "$HAS_SOCAT" == "true" ]]; then
  # Host-side test: daemon accepts "open URL\n" and dispatches to a stub.
  HOST_SOCK="/tmp/workenv-relay-test.sock"
  STUB_LOG="/tmp/workenv-relay-test.log"

  rm -f "$HOST_SOCK" "$STUB_LOG"
  WORKENV_RELAY_SOCK="$HOST_SOCK" \
  WORKENV_RELAY_OPENER="tee -a $STUB_LOG" \
  WORKENV_RELAY_NOTIFIER="tee -a $STUB_LOG" \
    bash "$(dirname "$0")/../bin/workenv-relay.sh" &
  sleep 0.5

  printf 'open https://example.com\n' | socat - UNIX-CONNECT:"$HOST_SOCK"
  sleep 0.2
  grep -q 'https://example.com' "$STUB_LOG"
  pass "relay dispatched open"

  printf 'notify hello\n' | socat - UNIX-CONNECT:"$HOST_SOCK"
  sleep 0.2
  grep -q 'hello' "$STUB_LOG"
  pass "relay dispatched notify"
else
  echo "SKIP: relay daemon tests (socat not installed on host)"
fi

# Test 3: container ships both shims under /usr/local/bin
build_image
for s in xdg-open notify-send; do
  out=$(docker run --rm "$IMAGE" ls /usr/local/bin/$s)
  [[ -n "$out" ]] || fail "$s shim missing"
done
pass "shims present in image"

# Test 4: shim prints warning and exits 0 when socket absent
out=$(docker run --rm "$IMAGE" xdg-open https://example.com 2>&1)
assert_contains "$out" "relay socket"
pass "xdg-open shim degrades gracefully"

if [[ "$HAS_SOCAT" == "true" ]]; then
  # Test 5: shim sends via socket when mounted
  HOST_SOCK_E2E="/tmp/workenv-relay-test-e2e.sock"
  STUB_LOG_E2E="/tmp/workenv-relay-test-e2e.log"
  rm -f "$HOST_SOCK_E2E" "$STUB_LOG_E2E"
  WORKENV_RELAY_SOCK="$HOST_SOCK_E2E" \
  WORKENV_RELAY_OPENER="tee -a $STUB_LOG_E2E" \
    bash "$(dirname "$0")/../bin/workenv-relay.sh" &
  sleep 0.5

  docker run --rm \
    -v "$HOST_SOCK_E2E":/run/host-relay/open.sock \
    "$IMAGE" xdg-open https://e2e.example >/dev/null
  sleep 0.2
  grep -q 'https://e2e.example' "$STUB_LOG_E2E"
  pass "shim → host relay → opener works end-to-end"

  kill %2 2>/dev/null || true
  rm -f "$HOST_SOCK_E2E" "$STUB_LOG_E2E"
else
  echo "SKIP: e2e relay test (socat not installed on host)"
fi
