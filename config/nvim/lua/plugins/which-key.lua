return {
  "folke/which-key.nvim",
  event = "UIEnter",
  config = function()
    require("which-key").setup({
      preset = "helix",
      spec = {
        { "<leader>f", group = "find" },
        { "<leader>s", group = "search" },
        { "<leader>c", group = "code" },
        { "<leader>g", group = "git" },
        { "<leader>b", group = "buffer" },
        { "<leader>w", group = "window" },
        { "<leader>j", group = "debug" },
        { "<leader>q", group = "session/quit" },
        { "<leader>u", group = "UI" },
      },
    })
  end,
}
