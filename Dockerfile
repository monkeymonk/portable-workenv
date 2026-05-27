# syntax=docker/dockerfile:1.6
FROM debian:12-slim

ARG USER_ID=1000
ARG GROUP_ID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Install core packages
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      locales \
      zsh \
      tmux \
      git \
      git-lfs \
      curl \
      wget \
      less \
      openssh-client \
      socat \
      jq \
      tree \
      unzip \
      tar \
      xz-utils \
      build-essential \
      cmake \
      ninja-build \
      pkg-config \
      python3 \
      python3-pip \
      python3-venv \
      shellcheck \
      chafa \
 && rm -rf /var/lib/apt/lists/* \
 && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
 && locale-gen

# Pinned tool versions
ARG RIPGREP_VERSION=14.1.1
ARG FD_VERSION=10.2.0
ARG FZF_VERSION=0.56.3
ARG BAT_VERSION=0.24.0
ARG DELTA_VERSION=0.18.2
ARG ZOXIDE_VERSION=0.9.6

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) rg_arch=x86_64-unknown-linux-musl; fd_arch=x86_64-unknown-linux-musl; fzf_arch=linux_amd64; bat_arch=x86_64-unknown-linux-musl; delta_arch=x86_64-unknown-linux-musl; zoxide_arch=x86_64-unknown-linux-musl ;; \
      arm64) rg_arch=aarch64-unknown-linux-gnu; fd_arch=aarch64-unknown-linux-gnu; fzf_arch=linux_arm64; bat_arch=aarch64-unknown-linux-gnu; delta_arch=aarch64-unknown-linux-gnu; zoxide_arch=aarch64-unknown-linux-musl ;; \
      *) echo "unsupported arch: $arch"; exit 1 ;; \
    esac; \
    tmp="$(mktemp -d)"; cd "$tmp"; \
    # ripgrep
    curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}-${rg_arch}.tar.gz" | tar xz; \
    install -m 0755 "ripgrep-${RIPGREP_VERSION}-${rg_arch}/rg" /usr/local/bin/rg; \
    # fd
    curl -fsSL "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-${fd_arch}.tar.gz" | tar xz; \
    install -m 0755 "fd-v${FD_VERSION}-${fd_arch}/fd" /usr/local/bin/fd; \
    # fzf
    curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-${fzf_arch}.tar.gz" | tar xz; \
    install -m 0755 fzf /usr/local/bin/fzf; \
    # bat
    curl -fsSL "https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/bat-v${BAT_VERSION}-${bat_arch}.tar.gz" | tar xz; \
    install -m 0755 "bat-v${BAT_VERSION}-${bat_arch}/bat" /usr/local/bin/bat; \
    # delta
    curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/delta-${DELTA_VERSION}-${delta_arch}.tar.gz" | tar xz; \
    install -m 0755 "delta-${DELTA_VERSION}-${delta_arch}/delta" /usr/local/bin/delta; \
    # zoxide
    curl -fsSL "https://github.com/ajeetdsouza/zoxide/releases/download/v${ZOXIDE_VERSION}/zoxide-${ZOXIDE_VERSION}-${zoxide_arch}.tar.gz" | tar xz; \
    install -m 0755 zoxide /usr/local/bin/zoxide; \
    # tree-sitter CLI
    ts_version=0.24.4; \
    case "$arch" in \
      amd64) ts_arch=x64 ;; \
      arm64) ts_arch=arm64 ;; \
    esac; \
    curl -fsSL -o /tmp/tree-sitter.gz "https://github.com/tree-sitter/tree-sitter/releases/download/v${ts_version}/tree-sitter-linux-${ts_arch}.gz"; \
    gunzip -c /tmp/tree-sitter.gz > /usr/local/bin/tree-sitter; \
    chmod 0755 /usr/local/bin/tree-sitter; \
    rm /tmp/tree-sitter.gz; \
    cd /; rm -rf "$tmp"

ARG NVIM_VERSION=v0.12.0

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) nvim_arch=linux-x86_64 ;; \
      arm64) nvim_arch=linux-arm64 ;; \
      *) echo "unsupported arch: $arch"; exit 1 ;; \
    esac; \
    tmp="$(mktemp -d)"; cd "$tmp"; \
    curl -fsSL "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-${nvim_arch}.tar.gz" | tar xz; \
    mkdir -p /opt/nvim; \
    mv "nvim-${nvim_arch}"/* /opt/nvim/; \
    chown -R root:root /opt/nvim; \
    ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim; \
    cd /; rm -rf "$tmp"

# oh-my-zsh + custom plugins at a shared location (read-only, shared across users)
RUN set -eux; \
    git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git /opt/oh-my-zsh; \
    mkdir -p /opt/oh-my-zsh/custom/plugins; \
    git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions.git \
      /opt/oh-my-zsh/custom/plugins/zsh-autosuggestions; \
    git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
      /opt/oh-my-zsh/custom/plugins/zsh-syntax-highlighting; \
    git clone --depth 1 https://github.com/jeffreytse/zsh-vi-mode.git \
      /opt/oh-my-zsh/custom/plugins/zsh-vi-mode; \
    chown -R root:root /opt/oh-my-zsh

# TPM — tmux plugin manager, shared location
RUN git clone --depth 1 https://github.com/tmux-plugins/tpm /opt/tpm

# mise — project runtime manager
ARG MISE_VERSION=v2026.3.0
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) mise_arch=x64 ;; \
      arm64) mise_arch=arm64 ;; \
    esac; \
    curl -fsSL "https://mise.run" | MISE_VERSION="$MISE_VERSION" MISE_INSTALL_PATH=/usr/local/bin/mise sh

# Pre-install Node LTS at a fixed path outside the volume mount.
ARG NODE_LTS_VERSION=22.11.0
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) node_arch=x64 ;; \
      arm64) node_arch=arm64 ;; \
    esac; \
    tmp="$(mktemp -d)"; cd "$tmp"; \
    curl -fsSL "https://nodejs.org/dist/v${NODE_LTS_VERSION}/node-v${NODE_LTS_VERSION}-linux-${node_arch}.tar.xz" | tar xJ; \
    mv "node-v${NODE_LTS_VERSION}-linux-${node_arch}" /opt/node; \
    cd /; rm -rf "$tmp"; \
    ln -sf /opt/node/bin/node /usr/local/bin/node; \
    ln -sf /opt/node/bin/npm /usr/local/bin/npm; \
    ln -sf /opt/node/bin/npx /usr/local/bin/npx

# Create non-root user (reuse existing group if GID already allocated)
RUN if ! getent group "$GROUP_ID" >/dev/null; then groupadd --gid "$GROUP_ID" dev; fi \
 && useradd --uid "$USER_ID" --gid "$GROUP_ID" -m -s /usr/bin/zsh dev

# Ship default shell config as image default. The entrypoint mkdir + cp pattern
# in the shell-config-seed step below will ensure it lands in the volume on
# first run without overwriting user edits.
COPY --chown=dev:dev config/zsh/  /opt/workenv-defaults/zsh/
COPY --chown=dev:dev config/nvim/ /opt/workenv-defaults/nvim/
COPY --chown=dev:dev config/tmux/ /opt/workenv-defaults/tmux/
RUN chmod +x /opt/workenv-defaults/tmux/scripts/*.sh

COPY --chown=dev:dev libexec/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

# Pre-create the full XDG tree under WORKENV_ROOT so:
#  (a) named-volume mounts inherit dev ownership;
#  (b) bind-mount overlays onto config/<app>/ don't cause Docker to create
#      the parent config/ dir as root (which would block the entrypoint's
#      mkdir of sibling dirs).
RUN mkdir -p /home/dev/.local/share/workenv-root/config/{nvim,tmux,zsh,mise} \
             /home/dev/.local/share/workenv-root/data/{nvim,tmux/plugins,mise} \
             /home/dev/.local/share/workenv-root/state/{nvim,tmux/sessions,zsh,mise} \
             /home/dev/.local/share/workenv-root/cache/{nvim,mise} \
 && chown -R dev:dev /home/dev/.local

# Host relay shims
COPY share/shims/xdg-open /usr/local/bin/xdg-open
COPY share/shims/notify-send /usr/local/bin/notify-send
RUN chmod 0755 /usr/local/bin/xdg-open /usr/local/bin/notify-send

USER dev
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/zsh"]
