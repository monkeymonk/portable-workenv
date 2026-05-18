#!/usr/bin/env bash
# Shared test helpers. Source this from each step's test script.
set -euo pipefail

IMAGE="${IMAGE:-workenv:test}"
TEST_VOLUME="${TEST_VOLUME:-workenv-test-root}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARKER="$REPO_ROOT/.tests-image-built"

build_image() {
  if [[ -f "$MARKER" ]] && [[ -z "$(find "$REPO_ROOT/Dockerfile" "$REPO_ROOT/config" "$REPO_ROOT/libexec" "$REPO_ROOT/bin" "$REPO_ROOT/share" -type f -newer "$MARKER" -print -quit)" ]]; then
    return 0
  fi
  echo "Building $IMAGE..."
  docker build \
    --build-arg USER_ID="$(id -u)" \
    --build-arg GROUP_ID="$(id -g)" \
    -t "$IMAGE" \
    "$REPO_ROOT"
  touch "$MARKER"
}

run_container() {
  docker run --rm \
    -v "$TEST_VOLUME":/home/dev/.local/share/workenv-root \
    "$IMAGE" "$@"
}

assert_contains() {
  local haystack="$1" needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "ASSERT FAIL: expected '$needle' in output, got:"
    echo "$haystack"
    exit 1
  fi
}

cleanup_test_volume() {
  docker volume rm "$TEST_VOLUME" 2>/dev/null || true
}

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; exit 1; }
