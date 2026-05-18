return {
  "christoomey/vim-tmux-navigator",
  keys = {
    { "<C-h>", mode = "n" },
    { "<C-j>", mode = "n" },
    { "<C-k>", mode = "n" },
    { "<C-l>", mode = "n" },
  },
  config = function()
    vim.g.tmux_navigator_no_mappings = 1
    local map = require("util.map").map
    map("n", "<C-h>", "<cmd>TmuxNavigateLeft<cr>", { desc = "Navigate left (tmux)" })
    map("n", "<C-j>", "<cmd>TmuxNavigateDown<cr>", { desc = "Navigate down (tmux)" })
    map("n", "<C-k>", "<cmd>TmuxNavigateUp<cr>", { desc = "Navigate up (tmux)" })
    map("n", "<C-l>", "<cmd>TmuxNavigateRight<cr>", { desc = "Navigate right (tmux)" })
  end,
}
