return {
  "antonk52/markdowny.nvim",
  ft = { "markdown" },
  config = function()
    require("markdowny").setup({
      filetypes = { "markdown" },
    })
    local map = require("util.map").map
    map("v", "<C-b>", function() require("markdowny").bold() end,      { desc = "MD: bold"      })
    map("v", "<C-i>", function() require("markdowny").italic() end,    { desc = "MD: italic"    })
    map("v", "<C-k>", function() require("markdowny").link() end,      { desc = "MD: link"      })
    map("v", "<C-e>", function() require("markdowny").code() end,      { desc = "MD: code"      })
  end,
}
