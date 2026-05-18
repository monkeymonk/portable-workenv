return {
  "folke/persistence.nvim",
  event = "BufReadPre",
  config = function()
    require("persistence").setup({
      dir = vim.fn.stdpath("state") .. "/sessions/",
      options = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp" },
    })
    local map = require("util.map").map
    map("n", "<leader>qs", function() require("persistence").load() end, { desc = "Restore session" })
    map("n", "<leader>qn", function() require("persistence").load({ last = true }) end, { desc = "Last session" })
    map("n", "<leader>qd", function() require("persistence").stop() end, { desc = "Stop session save" })
  end,
}
