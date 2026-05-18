#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

build_image

SRC="$(cd "$(dirname "$0")/.." && pwd)/libexec/_workenv-lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"; docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "^workenv:step17-proj-[a-f0-9]{8}$" | while read -r img; do docker image rm -f "$img" >/dev/null 2>&1 || true; done' EXIT

# ---------- Test 1: per-project Dockerfile builds a derived image ----------
proj="$tmp/step17-proj"
mkdir -p "$proj/.workenv"
cat > "$proj/.workenv/Dockerfile" <<EOF
FROM $IMAGE
USER root
RUN touch /step17-marker
USER dev
EOF

# Run the rebuild logic (uses sha256 stamp under XDG_DATA_HOME).
XDG_DATA_HOME="$tmp/data" bash -c "
  source '$SRC'
  workenv_maybe_rebuild_project '$proj'
"

img=$(bash -c "source '$SRC' && workenv_project_image '$proj'")
[[ "$img" =~ ^workenv:step17-proj-[a-f0-9]{8}$ ]] \
  || fail "unexpected derived image name: $img"
docker image inspect "$img" >/dev/null 2>&1 \
  || fail "derived image $img was not built"
pass "per-project Dockerfile builds derived image"

out=$(docker run --rm "$img" test -f /step17-marker && echo OK)
assert_contains "$out" "OK"
pass "derived image contains project layer"

# ---------- Test 2: workenv_project_image points launcher at derived image ----------
out=$(bash -c "source '$SRC' && workenv_project_image '$proj'")
assert_contains "$out" "$img"
pass "project_image resolves to derived tag"

# ---------- Test 3: rebuild stamp prevents redundant rebuilds ----------
before=$(docker image inspect -f '{{.Id}}' "$img")
XDG_DATA_HOME="$tmp/data" bash -c "
  source '$SRC'
  workenv_maybe_rebuild_project '$proj'
"
after=$(docker image inspect -f '{{.Id}}' "$img")
[[ "$before" == "$after" ]] || fail "image rebuilt despite unchanged Dockerfile"
pass "stamp prevents redundant rebuild"

# ---------- Test 4: .workenv/config/<app>/ overlay mounts read-only ----------
# We exercise the mount logic via a direct docker run rather than the full
# launcher (which requires PWD detection and tty). The lib's mount construction
# is tested in step16; here we sanity-check the actual overlay path.
mkdir -p "$proj/.workenv/config/nvim"
cat > "$proj/.workenv/config/nvim/init.lua" <<'EOF'
print("PROJECT_OVERLAY_ACTIVE")
EOF

vol="workenv-step17-vol"
docker volume rm "$vol" >/dev/null 2>&1 || true
out=$(docker run --rm \
  -v "$vol":/home/dev/.local/share/workenv-root \
  -v "$proj/.workenv/config/nvim":/home/dev/.local/share/workenv-root/config/nvim:ro \
  "$IMAGE" \
  nvim --headless +qa 2>&1 || true)
assert_contains "$out" "PROJECT_OVERLAY_ACTIVE"
pass "project config/nvim overlay replaces volume's nvim config"
docker volume rm "$vol" >/dev/null 2>&1 || true
