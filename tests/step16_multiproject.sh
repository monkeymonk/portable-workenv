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

# Test 11: workenv_container_path maps subpaths but NOT name-prefix siblings.
# Regression for the prefix bug: project /p must not capture /projector/... .
out=$(bash -c "source '$SRC' && workenv_container_path /home/me/proj /home/me/proj/src/x.lua")
[[ "$out" == "/workspace/src/x.lua" ]] || fail "subpath mapping wrong: $out"
out=$(bash -c "source '$SRC' && workenv_container_path /home/me/proj /home/me/proj")
[[ "$out" == "/workspace" ]] || fail "project-root mapping wrong: $out"
out=$(bash -c "source '$SRC' && workenv_container_path /home/me/proj /home/me/projector/x.lua")
[[ "$out" == "/home/me/projector/x.lua" ]] || fail "sibling path wrongly captured: $out"
pass "container path maps subpaths, leaves name-prefix siblings alone"

# Test 12: empty env/mount arrays must not poison the spec hash.
# Regression for the ${arr[@]:-} drift bug: an empty WORKENV_FLAG_ENVS expanded
# to a single empty string and produced a different hash than a truly-empty run.
out=$(bash -c '
  unset HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy
  source "'"$SRC"'"
  cleanproj=$(mktemp -d)
  workenv_load_config "$cleanproj"
  workenv_prepare_runtime workenv-clean "$cleanproj"
  for e in "${WORKENV_RUN_ENV_SPECS[@]+"${WORKENV_RUN_ENV_SPECS[@]}"}"; do
    [[ -n "$e" ]] || { echo PHANTOM_EMPTY_ENV; break; }
  done
  for m in "${WORKENV_RUN_MOUNT_SPECS[@]+"${WORKENV_RUN_MOUNT_SPECS[@]}"}"; do
    [[ -n "$m" ]] || { echo PHANTOM_EMPTY_MOUNT; break; }
  done
  h1=$WORKENV_RUN_SPEC_HASH
  workenv_prepare_runtime workenv-clean "$cleanproj"
  h2=$WORKENV_RUN_SPEC_HASH
  [[ "$h1" == "$h2" ]] && echo STABLE || echo UNSTABLE
  rm -rf "$cleanproj"
')
[[ "$out" != *PHANTOM* ]] || fail "empty array produced a phantom spec entry: $out"
assert_contains "$out" "STABLE"
pass "empty env/mount arrays do not poison the spec hash"

# Test 13: --config <app>=<path> mounts a host-global per-app config override.
out=$(bash -c "source '$SRC' && workenv_parse_flags --config zsh=/tmp/myzsh && workenv_load_config '$proj' && workenv_prepare_runtime workenv-x '$proj'; printf '%s\n' \"\${WORKENV_RUN_MOUNT_SPECS[@]}\"")
assert_contains "$out" "/tmp/myzsh:/home/dev/.local/share/workenv-root/config/zsh:ro"
pass "--config zsh= mounts host-global zsh config"

# Test 14: WORKENV_TMUX_CONFIG env maps to the tmux config mount.
out=$(bash -c "source '$SRC' && WORKENV_TMUX_CONFIG=/tmp/mytmux workenv_load_config '$proj' && workenv_prepare_runtime workenv-x '$proj'; printf '%s\n' \"\${WORKENV_RUN_MOUNT_SPECS[@]}\"")
assert_contains "$out" "/tmp/mytmux:/home/dev/.local/share/workenv-root/config/tmux:ro"
pass "WORKENV_TMUX_CONFIG maps to tmux config mount"

# Test 15: --override-config remains an alias for the nvim app.
out=$(bash -c "source '$SRC' && workenv_parse_flags --override-config /tmp/mynvim && workenv_load_config '$proj' && workenv_prepare_runtime workenv-x '$proj'; printf '%s\n' \"\${WORKENV_RUN_MOUNT_SPECS[@]}\"")
assert_contains "$out" "/tmp/mynvim:/home/dev/.local/share/workenv-root/config/nvim:ro"
pass "--override-config still maps to nvim"

# Test 16: unknown app to --config is rejected.
if bash -c "source '$SRC' && workenv_parse_flags --config bogus=/tmp/x" 2>/dev/null; then
  fail "--config accepted an unknown app"
fi
pass "--config rejects unknown app"
