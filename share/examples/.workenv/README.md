# Per-project workenv overrides

Drop a `.workenv/` directory at the root of any project to customise its
container without forking the workenv repo. Every entry below is optional.

```
<project-root>/
  .workenv/
    env                   # shell file sourced by the launcher (env vars)
    Dockerfile            # extends `workenv:latest` — builds `workenv:<project>`
    config/
      nvim/               # mounted read-only over the volume's nvim config
      tmux/               # same for tmux
      zsh/                # same for zsh
```

## env

Sourced before the container starts. See `env` in this directory for the
full list of supported variables.

## Dockerfile

If present, the launcher builds a derived image
(`workenv:<sanitized-project-name>`) before each run and uses it for the
project's container. The base `workenv:latest` image is built first;
the project image extends it.

Build context is the **project root** (so `COPY ./pyproject.toml /app/`
works). Add a `.dockerignore` to keep it small.

The launcher tracks the SHA-256 hash of `.workenv/Dockerfile`. When the file
changes, the project image rebuilds on the next launch. Force a rebuild with
`shellc --rebuild`.

## config/{nvim,tmux,zsh}

If a subdirectory exists, it replaces the volume's bundled config for that
app — read-only, overlaid at container start. Layout mirrors `~/.config/`,
so `.workenv/config/nvim/` has the same shape as `~/.config/nvim/` (and as
the workenv repo's `config/nvim/`).

Useful when one project needs a slimmer plugin set, a different colorscheme,
or project-specific tmux bindings.

## Activation

Copy this directory into your project, rename `Dockerfile.example` to
`Dockerfile` if you want image extension, edit `env` for variables, drop
config overrides under `config/`. Then just `shellc` from the project root.
