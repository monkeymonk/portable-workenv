local ensure_installed = {
  "bash", "css", "dockerfile", "go", "gomod", "gosum", "gowork",
  "html", "javascript", "json", "lua", "markdown", "markdown_inline",
  "python", "query", "rust", "tsx", "typescript", "vim", "vimdoc",
  "yaml", "toml",
}

return {
  "nvim-treesitter/nvim-treesitter",
  version = "master",
  config = function()
    require("nvim-treesitter.configs").setup({
      ensure_installed = ensure_installed,
      auto_install = true,
      sync_install = false,
      highlight = { enable = true },
      indent = { enable = true },
    })
  end,
}
