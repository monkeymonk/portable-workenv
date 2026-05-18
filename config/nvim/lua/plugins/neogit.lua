return {
  {
    "nvim-lua/plenary.nvim",
  },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
  },
  {
    "NeogitOrg/neogit",
    dependencies = { "nvim-lua/plenary.nvim", "sindrets/diffview.nvim" },
    cmd = { "Neogit" },
    config = function()
      require("neogit").setup({
        integrations = {
          diffview = true,
        },
        graph_style = "unicode",
      })
      local map = require("util.map").map
      map("n", "<leader>gg", "<cmd>Neogit<cr>", { desc = "Neogit" })
      map("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", { desc = "Diffview" })
      map("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", { desc = "File history" })
    end,
  },
}
