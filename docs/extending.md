# Extending workenv

## Add a Neovim plugin

1. Create a file in `config/nvim/lua/plugins/your-plugin.lua` that returns a spec
   table (or list of tables). The loader at `config/nvim/lua/util/pack/` auto-picks
   it up.
2. Rebuild the image: `workenv shell --rebuild` or `docker build ...` from the
   repo.
3. First launch triggers install; afterwards the plugin persists in the
   volume.

Example spec:

```lua
return {
  "folke/todo-comments.nvim",
  event = "BufReadPost",
  config = function()
    require("todo-comments").setup({})
  end,
}
```

Trigger keys: `event`, `cmd`, `ft`, `keys`. Omit all for eager loading.

## Add an LSP server

Edit `config/nvim/lua/plugins/mason.lua` and append to `ensure_installed`:

```lua
ensure_installed = { "lua_ls", "ts_ls", ..., "your_server" },
```

LSP config lives in `config/nvim/lua/config/lsp.lua` using
`vim.lsp.config("your_server", {...})` + `vim.lsp.enable("your_server")`.

## Add a formatter or linter

- Formatter: edit `config/nvim/lua/plugins/conform.lua` → `formatters_by_ft`.
- Linter: edit `config/nvim/lua/plugins/nvim-lint.lua` → `linters_by_ft`.
- Install the binary via Mason by adding to `mason-tool-installer`.

## Add a system tool — per-project (recommended)

Drop a `.workenv/Dockerfile` at the project root that extends the base:

```dockerfile
FROM workenv:latest
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
      your-tool \
 && rm -rf /var/lib/apt/lists/*
USER dev
```

The launcher detects it, builds `workenv:<project>` on next run, and uses
that image instead of the base. No fork, no impact on other projects. See
`share/examples/.workenv/` for the full template.

The build context is the project root, so add a `.workenv/.dockerignore` (or a
project-root `.dockerignore`) to keep large or sensitive trees out of the
context. The launcher warns once per project when the context exceeds
`WORKENV_DOCKERIGNORE_WARN_MB` MB (default `100`) and no `.dockerignore` is
present.

## Add a system tool — globally (everyone gets it)

Edit the APT block in the repo's root `Dockerfile`:

```dockerfile
RUN apt-get update && apt-get install --no-install-recommends -y \
    ... \
    your-tool
```

Rebuild: `workenv shell --rebuild`. Use this only when you want the tool in
every project.

## Config layers

Configuration for nvim, zsh, and tmux is built from three layers:

- **core** — host integration (clipboard relay, `gx`/open routing) baked into
  the image. Always loaded, even under a foreign config: Neovim runs through a
  wrapper that injects the baked core onto `packpath`, and tmux is started with
  `-f /opt/workenv/tmux-core.conf`, which then sources your config. So a
  mounted foreign config still gets host clipboard + open. Opt out per tool
  with `vim.g.workenv_core_clipboard = false` / `vim.g.workenv_core_open =
  false`, or disable the nvim core injection entirely with env
  `WORKENV_NVIM_NO_CORE=1`.
- **config** — the swappable opinionated layer (ours, or bring your own).
- **local** — small additive tweaks without forking: `lua/config/user.lua`
  (nvim, loaded last), `$ZDOTDIR/.zshrc.local` (zsh), `tmux.local.conf` (tmux).
  These live in the volume, survive image rebuilds, and are yours to gitignore.

## Bring your own config

Replace the **config** layer for one or more apps. Two routes:

- **Host-wide:** mount a host config dir read-only over an app's config.

  ```bash
  workenv shell --config nvim=$HOME/.config/nvim
  workenv shell --config zsh=$HOME/.config/zsh
  workenv shell --config tmux=$HOME/.config/tmux
  ```

  `--override-config <path>` is an alias for `--config nvim=<path>`. Env
  equivalents (set in `.workenv/env` or global config): `WORKENV_NVIM_CONFIG`,
  `WORKENV_ZSH_CONFIG`, `WORKENV_TMUX_CONFIG`. The repo's `config/<app>/`
  mirrors `~/.config/<app>/` 1:1, so a fork or symlink works without path
  translation.
- **Per-project:** `.workenv/config/{nvim,zsh,tmux}/` at the project root.
  Replaces the bundled config for that project only. Same shape as
  `~/.config/<app>/`.

A host-global override beats the per-project `.workenv/config/<app>/` overlay.
Because the **core** layer is baked into the image, any mounted config still
gets the host clipboard and open routing.

## Fork strategy

If your changes diverge significantly, fork this repo and set:

```bash
WORKENV_IMAGE="yourname/workenv:latest"
```

in `~/.config/workenv/config`.

## Contributing back

- Keep single-file plugin specs (no cross-file plugin deps).
- Add a test in `tests/stepN_*.sh` for any new image capability.
- Follow the ordered implementation discipline in the plan — don't skip
  steps.
