#!/usr/bin/env bash
# Shared helpers for workenv launcher scripts.
# Sourced by bin/shellc, bin/tmuxc, bin/nvimc.
set -eu

WORKENV_IMAGE="${WORKENV_IMAGE:-workenv:latest}"
WORKENV_VOLUME="${WORKENV_VOLUME:-workenv-root}"

# Platform detection.
case "$(uname -s)" in
  Linux*)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      WORKENV_PLATFORM="wsl"
    else
      WORKENV_PLATFORM="linux"
    fi
    ;;
  Darwin*)  WORKENV_PLATFORM="macos" ;;
  *)        WORKENV_PLATFORM="unknown" ;;
esac
export WORKENV_PLATFORM

# Flag state (populated by workenv_parse_flags; consumed by workenv_start_container).
WORKENV_FLAG_SSH_KEYS=false
WORKENV_FLAG_DOCKER=false
WORKENV_FLAG_EXTRA_MOUNTS=()
WORKENV_FLAG_ENVS=()
WORKENV_FLAG_OVERRIDE_CONFIG=""
WORKENV_FLAG_NAME=""
WORKENV_FLAG_REBUILD=false
WORKENV_FLAG_FORCE_RESTART=false
WORKENV_FLAG_NO_RESTART=false
WORKENV_POSITIONAL=()

WORKENV_DEFAULT_ENV_PASSTHROUGH=(
  HTTP_PROXY HTTPS_PROXY NO_PROXY
  http_proxy https_proxy no_proxy
)

workenv_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$@" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$@" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 -r "$@" | awk '{print $1}'
  else
    echo "workenv: missing sha256 tool (install coreutils, Perl shasum, or openssl)" >&2
    return 1
  fi
}

workenv_sha256_text() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    printf '%s' "$1" | openssl dgst -sha256 -r | awk '{print $1}'
  else
    echo "workenv: missing sha256 tool (install coreutils, Perl shasum, or openssl)" >&2
    return 1
  fi
}

workenv_sanitize_name() {
  local raw="$1" name
  name="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g; s/^-*//; s/-*$//; s/--*/-/g')"
  printf '%s\n' "${name:-project}"
}

WORKENV_BUILD_ARGS=()

workenv_prepare_proxy_build_args() {
  WORKENV_BUILD_ARGS=()
  local key
  for key in "${WORKENV_DEFAULT_ENV_PASSTHROUGH[@]}"; do
    if [[ -n "${!key+x}" ]]; then
      WORKENV_BUILD_ARGS+=( --build-arg "$key=${!key}" )
    fi
  done
}

workenv_docker_build() {
  local err rc
  err="$(mktemp)"
  if docker build "$@" 2>"$err"; then
    rm -f "$err"
    return 0
  fi
  rc=$?
  cat "$err" >&2
  if grep -qiE 'buildx component is missing|BuildKit is enabled|buildx' "$err"; then
    echo "workenv: Docker BuildKit/buildx failed; retrying with DOCKER_BUILDKIT=0 ..." >&2
    rm -f "$err"
    DOCKER_BUILDKIT=0 docker build "$@"
    return $?
  fi
  rm -f "$err"
  return "$rc"
}

workenv_parse_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ssh-keys)         WORKENV_FLAG_SSH_KEYS=true; shift ;;
      --docker)           WORKENV_FLAG_DOCKER=true; shift ;;
      --mount)
        [[ $# -ge 2 ]] || { echo "missing value for --mount" >&2; return 2; }
        WORKENV_FLAG_EXTRA_MOUNTS+=("$2"); shift 2 ;;
      --env)
        [[ $# -ge 2 ]] || { echo "missing value for --env" >&2; return 2; }
        WORKENV_FLAG_ENVS+=("$2"); shift 2 ;;
      --override-config)
        [[ $# -ge 2 ]] || { echo "missing value for --override-config" >&2; return 2; }
        WORKENV_FLAG_OVERRIDE_CONFIG="$2"; shift 2 ;;
      --name)
        [[ $# -ge 2 ]] || { echo "missing value for --name" >&2; return 2; }
        WORKENV_FLAG_NAME="$2"; shift 2 ;;
      --rebuild)          WORKENV_FLAG_REBUILD=true; shift ;;
      --force-restart)    WORKENV_FLAG_FORCE_RESTART=true; shift ;;
      --no-restart)       WORKENV_FLAG_NO_RESTART=true; shift ;;
      --)                 shift; WORKENV_POSITIONAL+=("$@"); return 0 ;;
      -*)                 echo "unknown flag: $1" >&2; return 2 ;;
      *)                  WORKENV_POSITIONAL+=("$1"); shift ;;
    esac
  done
}

workenv_load_config() {
  local project="${1:-$PWD}"
  local global="${XDG_CONFIG_HOME:-$HOME/.config}/workenv/config"
  [[ -f "$global" ]] && source "$global" || true

  # Legacy: .workenv was a file. It is now a directory; env vars live at .workenv/env.
  if [[ -f "$project/.workenv" ]] && [[ ! -d "$project/.workenv" ]]; then
    cat >&2 <<EOF
workenv: legacy .workenv file at $project/.workenv
  Migrate with:
    mv "$project/.workenv" "$project/.workenv.tmp" \\
      && mkdir "$project/.workenv" \\
      && mv "$project/.workenv.tmp" "$project/.workenv/env"
EOF
    return 1
  fi

  [[ -f "$project/.workenv/env" ]] && source "$project/.workenv/env" || true

  if [[ "${WORKENV_SSH_KEYS:-}" == "true" ]] && [[ "$WORKENV_FLAG_SSH_KEYS" == "false" ]]; then
    WORKENV_FLAG_SSH_KEYS=true
  fi
  if [[ "${WORKENV_DOCKER:-}" == "true" ]] && [[ "$WORKENV_FLAG_DOCKER" == "false" ]]; then
    WORKENV_FLAG_DOCKER=true
  fi
  if [[ -n "${WORKENV_NVIM_CONFIG:-}" ]] && [[ -z "$WORKENV_FLAG_OVERRIDE_CONFIG" ]]; then
    WORKENV_FLAG_OVERRIDE_CONFIG="$WORKENV_NVIM_CONFIG"
  fi
  if [[ -n "${WORKENV_NAME:-}" ]] && [[ -z "$WORKENV_FLAG_NAME" ]]; then
    WORKENV_FLAG_NAME="$WORKENV_NAME"
  fi
  if [[ -n "${WORKENV_EXTRA_MOUNTS:-}" ]]; then
    local m
    for m in $WORKENV_EXTRA_MOUNTS; do
      WORKENV_FLAG_EXTRA_MOUNTS+=("$m")
    done
  fi
  local e
  for e in ${WORKENV_ENV_VARS:-} ${WORKENV_ENV:-}; do
    [[ -n "$e" ]] && WORKENV_FLAG_ENVS+=("$e")
  done
}

# Resolve the image to use for a given project directory.
# Returns workenv:<sanitized-name> if .workenv/Dockerfile exists; else $WORKENV_IMAGE.
workenv_project_image() {
  local project="${1:-$PWD}"
  if [[ -f "$project/.workenv/Dockerfile" ]]; then
    local cname
    cname="$(workenv_container_name "$project")"
    printf '%s\n' "workenv:${cname#workenv-}"
  else
    printf '%s\n' "$WORKENV_IMAGE"
  fi
}

# Build/rebuild the per-project derived image if .workenv/Dockerfile exists.
workenv_maybe_rebuild_project() {
  local project="${1:-$PWD}"
  [[ -f "$project/.workenv/Dockerfile" ]] || return 0
  local img stamp_dir stamp current stored="" rebuild=false
  img="$(workenv_project_image "$project")"
  stamp_dir="${XDG_DATA_HOME:-$HOME/.local/share}/workenv"
  mkdir -p "$stamp_dir"
  stamp="$stamp_dir/.project.${img##*:}.sha256"
  local dockerfile_hash base_id
  dockerfile_hash="$(workenv_sha256 "$project/.workenv/Dockerfile")"
  base_id="$(docker image inspect -f '{{.Id}}' "$WORKENV_IMAGE" 2>/dev/null || true)"
  current="$(workenv_sha256_text "$dockerfile_hash"$'\n'"$WORKENV_IMAGE"$'\n'"$base_id")"
  [[ -f "$stamp" ]] && stored="$(cat "$stamp")"
  if [[ "$WORKENV_FLAG_REBUILD" == "true" ]]; then
    rebuild=true
  elif [[ "$current" != "$stored" ]]; then
    rebuild=true
  elif ! docker image inspect "$img" >/dev/null 2>&1; then
    rebuild=true
  fi
  if [[ "$rebuild" == "true" ]]; then
    echo "workenv: building project image $img ..." >&2
    workenv_prepare_proxy_build_args
    workenv_docker_build "${WORKENV_BUILD_ARGS[@]}" -f "$project/.workenv/Dockerfile" -t "$img" "$project"
    printf '%s' "$current" > "$stamp"
  fi
}

workenv_maybe_rebuild() {
  local repo_root="$1"
  local stamp_dir="${XDG_DATA_HOME:-$HOME/.local/share}/workenv"
  local stamp="$stamp_dir/.dockerfile.sha256"
  mkdir -p "$stamp_dir"
  local current_hash=""
  if [[ -f "$repo_root/Dockerfile" ]]; then
    current_hash="$(workenv_sha256 "$repo_root/Dockerfile")"
  else
    return 0
  fi
  local stored_hash=""
  [[ -f "$stamp" ]] && stored_hash="$(cat "$stamp")"
  local rebuild=false
  if [[ "$WORKENV_FLAG_REBUILD" == "true" ]]; then
    rebuild=true
  elif [[ "$current_hash" != "$stored_hash" ]]; then
    rebuild=true
  elif ! docker image inspect "$WORKENV_IMAGE" >/dev/null 2>&1; then
    rebuild=true
  fi
  if [[ "$rebuild" == "true" ]]; then
    echo "workenv: building image $WORKENV_IMAGE ..." >&2
    local build_args=()
    case "$WORKENV_PLATFORM" in
      linux|wsl) build_args=( --build-arg "USER_ID=$(id -u)" --build-arg "GROUP_ID=$(id -g)" ) ;;
    esac
    workenv_prepare_proxy_build_args
    workenv_docker_build "${build_args[@]}" "${WORKENV_BUILD_ARGS[@]}" -t "$WORKENV_IMAGE" "$repo_root"
    printf '%s' "$current_hash" > "$stamp"
  fi
}

# Derive container name from a directory path.
# Example: /home/me/works/my-app -> workenv-my-app-a1b2c3d4
workenv_container_name() {
  local dir="${1:-$PWD}"
  if [[ -n "$WORKENV_FLAG_NAME" ]]; then
    printf 'workenv-%s\n' "$(workenv_sanitize_name "$WORKENV_FLAG_NAME")"
    return 0
  fi
  local name hash
  name="$(workenv_sanitize_name "$(basename "$dir")")"
  hash="$(workenv_sha256_text "$dir")"
  printf 'workenv-%s-%s\n' "$name" "${hash:0:8}"
}

# Return 0 if container with given name exists and is running.
workenv_container_running() {
  local name="$1"
  [[ "$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || echo false)" == "true" ]]
}

# Return 0 if container with given name exists (any state).
workenv_container_exists() {
  local name="$1"
  docker inspect "$name" >/dev/null 2>&1
}

workenv_relay_socket() {
  case "$WORKENV_PLATFORM" in
    linux|wsl) printf '%s\n' "${XDG_RUNTIME_DIR:-/tmp}/workenv-relay.sock" ;;
    macos)     printf '%s\n' "${TMPDIR:-/tmp}workenv-relay.sock" ;;
    *)         printf '%s\n' "/tmp/workenv-relay.sock" ;;
  esac
}

workenv_maybe_start_relay() {
  [[ "${WORKENV_RELAY_AUTO_START:-true}" == "true" ]] || return 0
  [[ -n "${WORKENV_REPO_ROOT:-}" ]] || return 0
  [[ -x "$WORKENV_REPO_ROOT/bin/workenv-relay.sh" ]] || return 0

  if ! command -v socat >/dev/null 2>&1; then
    if [[ -z "${_WORKENV_RELAY_SOCAT_WARNED:-}" ]]; then
      cat >&2 <<'EOF'
workenv: 'socat' not found on host — host relay disabled.
  Without the relay, Neovim falls back to OSC 52 copy-only (paste from host won't work),
  and xdg-open / notify-send from inside the container won't reach the host.
  Install:
    Arch:          sudo pacman -S socat
    Debian/Ubuntu: sudo apt install socat
    macOS:         brew install socat
  Then run 'workenv restart' to remount the relay socket.
  Silence this with WORKENV_RELAY_AUTO_START=false.
EOF
      export _WORKENV_RELAY_SOCAT_WARNED=1
    fi
    return 0
  fi

  local relay_sock
  relay_sock="$(workenv_relay_socket)"
  [[ -S "$relay_sock" ]] && return 0

  nohup "$WORKENV_REPO_ROOT/bin/workenv-relay.sh" >/dev/null 2>&1 &
  local relay_pid=$!
  local _
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if [[ -S "$relay_sock" ]]; then
      echo "workenv: started host relay (pid $relay_pid, $relay_sock) for clipboard + xdg-open. Set WORKENV_RELAY_AUTO_START=false to disable." >&2
      return 0
    fi
    sleep 0.1
  done
  echo "workenv: relay daemon did not produce a socket at $relay_sock within 1s" >&2
}

WORKENV_RUN_MOUNTS=()
WORKENV_RUN_ENVS=()
WORKENV_RUN_MOUNT_SPECS=()
WORKENV_RUN_ENV_SPECS=()
WORKENV_RUN_LABELS=()
WORKENV_RUN_IMAGE=""
WORKENV_RUN_IMAGE_ID=""
WORKENV_RUN_SPEC_HASH=""

workenv_add_mount() {
  local spec="$1"
  [[ -n "$spec" ]] || return 0
  WORKENV_RUN_MOUNTS+=( -v "$spec" )
  WORKENV_RUN_MOUNT_SPECS+=( "$spec" )
}

workenv_add_env_arg() {
  local item="$1" key value
  [[ -n "$item" ]] || return 0
  if [[ "$item" == *=* ]]; then
    key="${item%%=*}"
    value="${item#*=}"
    [[ -n "$key" ]] || return 0
    if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      echo "workenv: invalid env name: $key" >&2
      return 1
    fi
    WORKENV_RUN_ENVS+=( -e "$key=$value" )
    WORKENV_RUN_ENV_SPECS+=( "$key=$value" )
  else
    key="$item"
    if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      echo "workenv: invalid env name: $key" >&2
      return 1
    fi
    if [[ -n "${!key+x}" ]]; then
      WORKENV_RUN_ENVS+=( -e "$key=${!key}" )
      WORKENV_RUN_ENV_SPECS+=( "$key=${!key}" )
    fi
  fi
}

workenv_b64encode() {
  if [[ $# -eq 0 ]]; then
    printf '' | base64 | tr -d '\n'
  else
    printf '%s\n' "$@" | base64 | tr -d '\n'
  fi
}

workenv_b64decode() {
  printf '%s' "$1" | base64 -d 2>/dev/null || true
}

workenv_prepare_runtime() {
  local name="$1" project="$2"

  WORKENV_RUN_MOUNTS=()
  WORKENV_RUN_ENVS=()
  WORKENV_RUN_MOUNT_SPECS=()
  WORKENV_RUN_ENV_SPECS=()

  workenv_add_mount "$WORKENV_VOLUME:/home/dev/.local/share/workenv-root"
  workenv_add_mount "$project:/workspace"

  # Pass common proxy variables automatically, then any explicit allowlist or
  # KEY=value assignments from --env, WORKENV_ENV, or WORKENV_ENV_VARS.
  local e
  for e in "${WORKENV_DEFAULT_ENV_PASSTHROUGH[@]}" "${WORKENV_FLAG_ENVS[@]:-}"; do
    workenv_add_env_arg "$e"
  done

  # SSH agent forwarding (auto)
  if [[ -n "${SSH_AUTH_SOCK:-}" ]] && [[ -S "$SSH_AUTH_SOCK" ]]; then
    workenv_add_mount "$SSH_AUTH_SOCK:/run/host-ssh/agent.sock"
  fi

  # --ssh-keys: mount ~/.ssh read-only
  if [[ "$WORKENV_FLAG_SSH_KEYS" == "true" ]] && [[ -d "$HOME/.ssh" ]]; then
    workenv_add_mount "$HOME/.ssh:/home/dev/.ssh:ro"
  fi

  # Auto-mount ~/.gitconfig read-only
  if [[ -f "$HOME/.gitconfig" ]]; then
    workenv_add_mount "$HOME/.gitconfig:/home/dev/.gitconfig:ro"
  fi

  # Auto-mount ssh config + known_hosts read-only (even without --ssh-keys)
  if [[ -f "$HOME/.ssh/config" ]]; then
    workenv_add_mount "$HOME/.ssh/config:/home/dev/.ssh/config:ro"
  fi
  if [[ -f "$HOME/.ssh/known_hosts" ]]; then
    workenv_add_mount "$HOME/.ssh/known_hosts:/home/dev/.ssh/known_hosts:ro"
  fi

  # --docker: mount docker socket
  if [[ "$WORKENV_FLAG_DOCKER" == "true" ]] && [[ -S /var/run/docker.sock ]]; then
    workenv_add_mount "/var/run/docker.sock:/var/run/docker.sock"
  fi

  # Host relay socket (if daemon is running)
  workenv_maybe_start_relay
  local relay_sock
  relay_sock="$(workenv_relay_socket)"
  if [[ -S "$relay_sock" ]]; then
    workenv_add_mount "$relay_sock:/run/host-relay/open.sock"
  fi

  # --mount <path>: extra bind mounts
  local m
  for m in "${WORKENV_FLAG_EXTRA_MOUNTS[@]:-}"; do
    [[ -n "$m" ]] || continue
    local base
    base="$(basename "$m")"
    workenv_add_mount "$m:/extra/$base"
  done

  # --override-config <path>: mount user's nvim config (explicit opt-in)
  if [[ -n "$WORKENV_FLAG_OVERRIDE_CONFIG" ]]; then
    workenv_add_mount "$WORKENV_FLAG_OVERRIDE_CONFIG:/home/dev/.local/share/workenv-root/config/nvim:ro"
  fi

  # Per-project config overlays at .workenv/config/<app>/ — replace volume's defaults
  if [[ -d "$project/.workenv/config" ]]; then
    local app
    for app in nvim tmux zsh; do
      if [[ -d "$project/.workenv/config/$app" ]]; then
        workenv_add_mount "$project/.workenv/config/$app:/home/dev/.local/share/workenv-root/config/$app:ro"
      fi
    done
  fi

  WORKENV_RUN_IMAGE="$(workenv_project_image "$project")"
  WORKENV_RUN_IMAGE_ID="$(docker image inspect -f '{{.Id}}' "$WORKENV_RUN_IMAGE" 2>/dev/null || printf '%s' "$WORKENV_RUN_IMAGE")"

  local mounts_b64 envs_b64
  mounts_b64="$(workenv_b64encode "${WORKENV_RUN_MOUNT_SPECS[@]}")"
  envs_b64="$(workenv_b64encode "${WORKENV_RUN_ENV_SPECS[@]}")"
  WORKENV_RUN_SPEC_HASH="$(workenv_sha256_text "$WORKENV_RUN_IMAGE_ID|$mounts_b64|$envs_b64")"

  WORKENV_RUN_LABELS=(
    --label "workenv.managed=true"
    --label "workenv.project=$project"
    --label "workenv.spec=$WORKENV_RUN_SPEC_HASH"
    --label "workenv.image_id=$WORKENV_RUN_IMAGE_ID"
    --label "workenv.mounts.b64=$mounts_b64"
    --label "workenv.envs.b64=$envs_b64"
  )
}

workenv_container_spec() {
  local name="$1"
  docker inspect -f '{{ index .Config.Labels "workenv.spec" }}' "$name" 2>/dev/null || true
}

workenv_container_label() {
  local name="$1" key="$2" out
  out="$(docker inspect -f "{{ index .Config.Labels \"$key\" }}" "$name" 2>/dev/null || true)"
  [[ "$out" == "<no value>" ]] && out=""
  printf '%s' "$out"
}

# Print a human-readable diff between the running container's stored runtime
# spec and the freshly computed WORKENV_RUN_* values. Output lines go to stderr.
workenv_print_spec_diff() {
  local name="$1"
  local old_image_id old_mounts_b64 old_envs_b64
  old_image_id="$(workenv_container_label "$name" workenv.image_id)"
  old_mounts_b64="$(workenv_container_label "$name" workenv.mounts.b64)"
  old_envs_b64="$(workenv_container_label "$name" workenv.envs.b64)"

  if [[ -z "$old_image_id" && -z "$old_mounts_b64" && -z "$old_envs_b64" ]]; then
    echo "  (container predates spec labels; full diff unavailable)" >&2
    return 0
  fi

  if [[ "$old_image_id" != "$WORKENV_RUN_IMAGE_ID" ]]; then
    printf '  image: %s -> %s\n' "${old_image_id:-<none>}" "$WORKENV_RUN_IMAGE_ID" >&2
  fi

  local old_mounts new_mounts line
  old_mounts="$(workenv_b64decode "$old_mounts_b64")"
  new_mounts="$(printf '%s\n' "${WORKENV_RUN_MOUNT_SPECS[@]}")"
  if [[ "$old_mounts" != "$new_mounts" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      grep -qxF -- "$line" <<< "$new_mounts" || printf '  - mount: %s\n' "$line" >&2
    done <<< "$old_mounts"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      grep -qxF -- "$line" <<< "$old_mounts" || printf '  + mount: %s\n' "$line" >&2
    done <<< "$new_mounts"
  fi

  local old_envs new_envs
  old_envs="$(workenv_b64decode "$old_envs_b64")"
  new_envs="$(printf '%s\n' "${WORKENV_RUN_ENV_SPECS[@]}")"
  if [[ "$old_envs" != "$new_envs" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      grep -qxF -- "$line" <<< "$new_envs" || printf '  - env: %s\n' "${line%%=*}" >&2
    done <<< "$old_envs"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      grep -qxF -- "$line" <<< "$old_envs" || printf '  + env: %s\n' "${line%%=*}" >&2
    done <<< "$new_envs"
  fi
}

# Prompt y/N on /dev/tty. Default no. Returns 0=yes, 1=no, 2=no tty available.
workenv_confirm_tty() {
  local prompt="$1" reply
  if ! { exec 3</dev/tty; } 2>/dev/null; then
    return 2
  fi
  printf '%s ' "$prompt" >&2
  IFS= read -r reply <&3 || reply=""
  exec 3<&-
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *)           return 1 ;;
  esac
}

# Start a new workenv container in detached mode.
# Arguments: container_name project_dir
workenv_start_container() {
  local name="$1" project="$2"
  workenv_prepare_runtime "$name" "$project"

  docker run -d \
    --name "$name" \
    "${WORKENV_RUN_LABELS[@]}" \
    "${WORKENV_RUN_MOUNTS[@]}" \
    "${WORKENV_RUN_ENVS[@]}" \
    -w /workspace \
    "$WORKENV_RUN_IMAGE" \
    sleep infinity >/dev/null
}

# Enter a running container with the given command.
workenv_exec() {
  local name="$1"; shift
  docker exec -it "$name" /usr/local/bin/entrypoint.sh "$@"
}

# Resolve drift action. Echoes one of: yes | no | prompt.
workenv_drift_decision() {
  if [[ "$WORKENV_FLAG_FORCE_RESTART" == "true" ]]; then
    printf 'yes\n'; return
  fi
  if [[ "$WORKENV_FLAG_NO_RESTART" == "true" ]]; then
    printf 'no\n'; return
  fi
  case "${WORKENV_AUTO_RESTART:-}" in
    yes|true|1)  printf 'yes\n'; return ;;
    no|false|0)  printf 'no\n'; return ;;
  esac
  printf 'prompt\n'
}

# Ensure container for this project is running; start if needed.
# Echoes the container name.
workenv_ensure_container() {
  local project="${1:-$PWD}"
  local name
  name="$(workenv_container_name "$project")"
  workenv_prepare_runtime "$name" "$project"
  if workenv_container_running "$name"; then
    local current_spec
    current_spec="$(workenv_container_spec "$name")"
    if [[ "$current_spec" != "$WORKENV_RUN_SPEC_HASH" ]]; then
      echo "workenv: container $name has drifted from current spec:" >&2
      workenv_print_spec_diff "$name"
      local decision
      decision="$(workenv_drift_decision)"
      if [[ "$decision" == "prompt" ]]; then
        if workenv_confirm_tty "workenv: recreate $name? running processes inside will be killed [y/N]"; then
          decision="yes"
        else
          local rc=$?
          if [[ $rc -eq 2 ]]; then
            echo "workenv: no tty for prompt; refusing to recreate. Use --force-restart, --no-restart, or set WORKENV_AUTO_RESTART={yes,no}." >&2
            return 1
          fi
          decision="no"
        fi
      fi
      if [[ "$decision" == "yes" ]]; then
        echo "workenv: recreating $name" >&2
        docker rm -f "$name" >/dev/null
        workenv_start_container "$name" "$project"
      else
        echo "workenv: keeping existing $name (spec drift retained; run 'workenv restart' to apply)" >&2
      fi
    fi
  elif workenv_container_exists "$name"; then
    docker rm -f "$name" >/dev/null
    workenv_start_container "$name" "$project"
  else
    workenv_start_container "$name" "$project"
  fi
  printf '%s\n' "$name"
}
