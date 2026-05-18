return {
  "nvimdev/lspsaga.nvim",
  event = "LspAttach",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
  },
  config = function()
    require("lspsaga").setup({
      ui = { border = "rounded" },
      symbol_in_winbar = { enable = false },
      lightbulb = { enable = false },
      outline = { auto_preview = false },
    })

    local map = require("util.map").map
    map("n", "K", "<cmd>Lspsaga hover_doc<cr>", { desc = "Hover (lspsaga)" })
    map("n", "gp", "<cmd>Lspsaga peek_definition<cr>", { desc = "Peek definition" })
    map("n", "<leader>co", "<cmd>Lspsaga outline<cr>", { desc = "Outline" })
  end,
}
