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
      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls", "ts_ls", "tailwindcss", "gopls", "rust_analyzer",
          "bashls", "pyright", "cssls", "html", "jsonls", "yamlls",
          "dockerls", "docker_compose_language_service", "emmet_ls",
        },
        automatic_installation = true,
      })
    end,
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim" },
    event = "VimEnter",
    config = function()
      local installer = require("mason-tool-installer")
      installer.setup({
        ensure_installed = {
          "stylua",
          "prettier",
          "shfmt",
          "shellcheck",
          "markdownlint",
          "yamllint",
          "eslint_d",
          "goimports",
        },
        auto_update = false,
        run_on_start = true,
        start_delay = 1000,
      })
      installer.run_on_start()
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
