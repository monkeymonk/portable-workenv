return {
  "nvim-treesitter/nvim-treesitter",
  version = "master",
  config = function()
    require("nvim-treesitter.configs").setup({
      -- Parsers install on demand when you first open a file of that type.
      -- We deliberately do NOT bulk-install via `ensure_installed`: on a fresh
      -- volume that fires ~20 concurrent download/extract jobs that race on
      -- temp tarballs ("tar: tree-sitter-<lang>.tar.gz: Cannot open ...").
      -- The legacy `master` installer has no concurrency cap, and
      -- `sync_install = true` would freeze startup for minutes while compiling.
      -- On-demand keeps it to 1-3 parsers at a time — no storm, no startup freeze.
      ensure_installed = { "bash", "lua", "vim", "query", "markdown", "markdown_inline", "json", "yaml" },
      auto_install = true,
      sync_install = false,
      highlight = { enable = true },
      indent = { enable = true },
    })
  end,
}
