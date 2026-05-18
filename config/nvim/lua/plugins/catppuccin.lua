return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  config = function()
    require("catppuccin").setup({
      flavour = "mocha",
      transparent_background = false,
      term_colors = true,
      integrations = {
        cmp = true,
        gitsigns = true,
        treesitter = true,
        mason = true,
        native_lsp = {
          enabled = true,
          virtual_text = {
            errors = { "italic" },
            hints = { "italic" },
            warnings = { "italic" },
            information = { "italic" },
          },
        },
        which_key = true,
        notify = true,
        neogit = true,
        dap = true,
        dap_ui = true,
        noice = true,
        snacks = { enabled = true },
      },
    })
    vim.cmd.colorscheme("catppuccin")
  end,
}
