# Extending workenv

## Add a Neovim plugin

1. Create a file in `config/nvim/lua/plugins/your-plugin.lua` that returns a spec
   table (or list of tables). The loader at `config/nvim/lua/util/pack/` auto-picks
   it up.
2. Rebuild the image: `shellc --rebuild` or `docker build ...` from the repo.
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

## Add a system tool — globally (everyone gets it)

Edit the APT block in the repo's root `Dockerfile`:

```dockerfile
RUN apt-get update && apt-get install --no-install-recommends -y \
    ... \
    your-tool
```

Rebuild: `shellc --rebuild`. Use this only when you want the tool in every
project.

## Override the entire nvim config

Two routes:

- **Host-wide:** `--override-config $HOME/.config/nvim` (or
  `WORKENV_NVIM_CONFIG=...` in global config). Same config for every project.
  The repo's `config/nvim/` mirrors `~/.config/nvim/` 1:1, so a fork or
  symlink works without path translation.
- **Per-project:** `.workenv/config/nvim/` at the project root. Replaces the
  bundled config for this project only. Same shape as `~/.config/nvim/`.

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
