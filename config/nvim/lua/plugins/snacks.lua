return {
  "folke/snacks.nvim",
  priority = 900,
  config = function()
    local snacks = require("snacks")
    snacks.setup({
      bigfile = { enabled = true },
      dashboard = {
        enabled = true,
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
        },
        preset = {
          header = [[
 __    __     ______     ______     __  __     ______     __   __     __   __
/\ "-./  \   /\  __ \   /\  ___\   /\ \/ /    /\  ___\   /\ "-.\ \   /\ \ / /
\ \ \-./\ \  \ \ \/\ \  \ \ \____  \ \  _"-.  \ \  __\   \ \ \-.  \  \ \ \'/
 \ \_\ \ \_\  \ \_____\  \ \_____\  \ \_\ \_\  \ \_____\  \ \_\\"\_\  \ \__|
  \/_/  \/_/   \/_____/   \/_____/   \/_/\/_/   \/_____/   \/_/ \/_/   \/_/
          ]],
        },
      },
      explorer = { enabled = true, replace_netrw = true },
      indent = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true, timeout = 3000 },
      picker = { enabled = true },
      quickfile = { enabled = true },
      scope = { enabled = true },
      scroll = { enabled = false },
      statuscolumn = { enabled = true },
      words = { enabled = true },
    })

    local map = require("util.map").map
    map("n", "<leader>ff", function() snacks.picker.files() end, { desc = "Find files" })
    map("n", "<leader>fg", function() snacks.picker.grep() end, { desc = "Grep" })
    map("n", "<leader>fb", function() snacks.picker.buffers() end, { desc = "Buffers" })
    map("n", "<leader>fh", function() snacks.picker.help() end, { desc = "Help" })
    map("n", "<leader>fe", function() snacks.explorer() end, { desc = "Explorer" })
    map("n", "<leader>fn", function() snacks.picker.notifications() end, { desc = "Notifications" })
    map("n", "<leader>un", function() snacks.notifier.hide() end, { desc = "Dismiss notifications" })
  end,
}
