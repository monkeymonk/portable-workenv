return {
  "danymat/neogen",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  cmd = { "Neogen" },
  config = function()
    require("neogen").setup({
      snippet_engine = "nvim",
    })
    local map = require("util.map").map
    map("n", "<leader>cg", function() require("neogen").generate() end, { desc = "Generate doc" })
  end,
}
