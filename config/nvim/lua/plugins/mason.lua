return {
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup({
        install_root_dir = vim.fn.stdpath("data") .. "/mason",
        ui = {
          border = "rounded",
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗",
          },
        },
      })
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      -- Server list comes from config.tools; needs_runtime servers (gopls,
      -- rust_analyzer) are excluded from auto-install because their runtime
      -- isn't baked in. They stay configured in config/lsp.lua and activate
      -- once installed. automatic_installation is off so enabling a server
      -- never triggers a runtime-dependent install behind the user's back.
      require("mason-lspconfig").setup({
        ensure_installed = require("config.tools").lsp_ensure_installed(),
        automatic_installation = false,
      })
    end,
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim" },
    event = "VimEnter",
    config = function()
      -- Tool list comes from config.tools; needs_runtime tools (goimports) are
      -- excluded from auto-install but stay wired into conform for use once the
      -- runtime is present.
      require("mason-tool-installer").setup({
        ensure_installed = require("config.tools").tool_ensure_installed(),
        auto_update = false,
        run_on_start = true,
        start_delay = 1000,
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason-lspconfig.nvim" },
    config = function()
      require("config.lsp")
    end,
  },
}
