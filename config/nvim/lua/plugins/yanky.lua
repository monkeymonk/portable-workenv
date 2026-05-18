return {
  "gbprod/yanky.nvim",
  config = function()
    require("yanky").setup({
      ring = { storage = "shada" },
      system_clipboard = { sync_with_ring = true },
    })

    local map = require("util.map").map
    map({ "n", "x" }, "y", "<Plug>(YankyYank)", { desc = "Yank" })
    map({ "n", "x" }, "p", "<Plug>(YankyPutAfter)", { desc = "Put after" })
    map({ "n", "x" }, "P", "<Plug>(YankyPutBefore)", { desc = "Put before" })
    map("n", "<c-n>", "<Plug>(YankyCycleForward)", { desc = "Yank cycle forward" })
    map("n", "<c-p>", "<Plug>(YankyCycleBackward)", { desc = "Yank cycle backward" })
    map("n", "<leader>y", function()
      require("snacks").picker.pick("yanky")
    end, { desc = "Yank history" })
  end,
}
