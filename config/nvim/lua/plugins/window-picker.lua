return {
  "s1n7ax/nvim-window-picker",
  keys = { "<leader>wp" },
  config = function()
    require("window-picker").setup({
      hint = "floating-big-letter",
      selection_chars = "FJDKSLA;CMRUEIWOQP",
    })
    local map = require("util.map").map
    map("n", "<leader>wp", function()
      local picked = require("window-picker").pick_window()
      if picked then vim.api.nvim_set_current_win(picked) end
    end, { desc = "Pick window" })
  end,
}
