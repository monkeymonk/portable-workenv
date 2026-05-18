#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

build_image

# Test 1: SSH_AUTH_SOCK exported by entrypoint
out=$(run_container sh -c 'echo ${SSH_AUTH_SOCK:-unset}')
assert_contains "$out" "/run/host-ssh/agent.sock"
pass "SSH_AUTH_SOCK exported to expected path"

# Test 2: openssh-client is installed
out=$(run_container ssh -V 2>&1)
assert_contains "$out" "OpenSSH"
pass "OpenSSH client present"

# Test 3: ssh-add can be invoked (no agent available here; expect exit 2 "no agent")
set +e
out=$(run_container ssh-add -l 2>&1)
rc=$?
set -e
# rc 2 means could not connect to agent; still proves binary runs
[[ "$rc" -eq 2 ]] || fail "ssh-add unexpected rc=$rc: $out"
pass "ssh-add runs (no agent in test)"
