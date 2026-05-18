#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

SRC="$(cd "$(dirname "$0")/.." && pwd)/libexec/_workenv-lib.sh"

# Test 1: loads global config if present
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/workenv"
cat > "$tmp/workenv/config" <<'EOF'
WORKENV_IMAGE="workenv:from-global"
WORKENV_SSH_KEYS=true
EOF
out=$(XDG_CONFIG_HOME="$tmp" bash -c "source '$SRC' && workenv_load_config; echo \$WORKENV_IMAGE \$WORKENV_FLAG_SSH_KEYS")
assert_contains "$out" "workenv:from-global true"
pass "global config loaded"

# Test 2: per-project .workenv/env overrides global
proj="$tmp/proj"
mkdir -p "$proj/.workenv"
cat > "$proj/.workenv/env" <<'EOF'
WORKENV_DOCKER=true
EOF
out=$(XDG_CONFIG_HOME="$tmp" bash -c "cd '$proj' && source '$SRC' && workenv_load_config '$proj'; echo \$WORKENV_FLAG_DOCKER")
assert_contains "$out" "true"
pass "per-project .workenv/env respected"

# Test 3: legacy .workenv file is rejected with migration message
legacy="$tmp/legacy"
mkdir -p "$legacy"
cat > "$legacy/.workenv" <<'EOF'
WORKENV_DOCKER=true
EOF
out=$(XDG_CONFIG_HOME="$tmp" bash -c "source '$SRC' && workenv_load_config '$legacy'" 2>&1 || true)
assert_contains "$out" "legacy .workenv file"
pass "legacy .workenv file rejected"

# Test 4: workenv_project_image returns base image when no .workenv/Dockerfile
out=$(bash -c "source '$SRC' && workenv_project_image '$proj'")
assert_contains "$out" "workenv:latest"
pass "project_image returns base when no Dockerfile"

# Test 5: workenv_project_image returns derived tag when .workenv/Dockerfile exists
withdf="$tmp/with-dockerfile"
mkdir -p "$withdf/.workenv"
echo "FROM workenv:latest" > "$withdf/.workenv/Dockerfile"
out=$(bash -c "source '$SRC' && workenv_project_image '$withdf'")
[[ "$out" =~ ^workenv:with-dockerfile-[a-f0-9]{8}$ ]] \
  || fail "unexpected derived image tag: $out"
pass "project_image returns derived tag with Dockerfile"

# Test 6: container name sanitization plus path hash avoids basename collisions
out=$(bash -c "source '$SRC' && workenv_container_name '/tmp/My.Big Project'")
[[ "$out" =~ ^workenv-my-big-project-[a-f0-9]{8}$ ]] \
  || fail "unexpected container name: $out"
pass "container name sanitization with hash"

# Test 7: WORKENV_NAME overrides default hashed name
named="$tmp/named"
mkdir -p "$named/.workenv"
cat > "$named/.workenv/env" <<'EOF'
WORKENV_NAME="Team API"
EOF
out=$(bash -c "source '$SRC' && workenv_load_config '$named' && workenv_container_name '$named'")
assert_contains "$out" "workenv-team-api"
pass "WORKENV_NAME overrides container name"

# Test 8: proxy/env passthrough is converted to docker -e args
envproj="$tmp/envproj"
mkdir -p "$envproj/.workenv"
cat > "$envproj/.workenv/env" <<'EOF'
WORKENV_ENV="FOO=bar BAZ"
BAZ="from-config"
HTTPS_PROXY="http://proxy.example"
EOF
out=$(bash -c "source '$SRC' && workenv_load_config '$envproj' && WORKENV_RUN_IMAGE=workenv:latest && workenv_prepare_runtime workenv-envproj '$envproj'; printf '%s\n' \"\${WORKENV_RUN_ENVS[@]}\"")
assert_contains "$out" "FOO=bar"
assert_contains "$out" "BAZ=from-config"
assert_contains "$out" "HTTPS_PROXY=http://proxy.example"
pass "env passthrough supports proxy defaults and explicit env"

# Test 9: runtime spec hash changes when runtime inputs change
out=$(bash -c "source '$SRC' && workenv_load_config '$envproj' && workenv_prepare_runtime workenv-envproj '$envproj'; first=\$WORKENV_RUN_SPEC_HASH; WORKENV_FLAG_ENVS+=(QUX=one); workenv_prepare_runtime workenv-envproj '$envproj'; second=\$WORKENV_RUN_SPEC_HASH; [[ \$first != \$second ]] && echo changed")
assert_contains "$out" "changed"
pass "runtime spec changes when env changes"

# Test 10: proxy variables are also prepared as Docker build args
out=$(bash -c "source '$SRC' && workenv_load_config '$envproj' && workenv_prepare_proxy_build_args; printf '%s\n' \"\${WORKENV_BUILD_ARGS[@]}\"")
assert_contains "$out" "HTTPS_PROXY=http://proxy.example"
pass "proxy vars are passed as build args"
