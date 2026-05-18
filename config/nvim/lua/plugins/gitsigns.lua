return {
  "lewis6991/gitsigns.nvim",
  event = "BufReadPost",
  config = function()
    require("gitsigns").setup({
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      on_attach = function(bufnr)
        local map = require("util.map").map
        local gs = require("gitsigns")
        map("n", "]h", function() gs.nav_hunk("next") end, { buffer = bufnr, desc = "Next hunk" })
        map("n", "[h", function() gs.nav_hunk("prev") end, { buffer = bufnr, desc = "Prev hunk" })
        map({ "n", "v" }, "<leader>gs", ":Gitsigns stage_hunk<cr>", { buffer = bufnr, desc = "Stage hunk" })
        map({ "n", "v" }, "<leader>gr", ":Gitsigns reset_hunk<cr>", { buffer = bufnr, desc = "Reset hunk" })
        map("n", "<leader>gp", gs.preview_hunk, { buffer = bufnr, desc = "Preview hunk" })
        map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, { buffer = bufnr, desc = "Blame line" })
      end,
    })
  end,
}
