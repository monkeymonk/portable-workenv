return {
  "maan2003/lsp_lines.nvim",
  event = "LspAttach",
  config = function()
    require("lsp_lines").setup()
    -- Off by default; virtual_text from diagnostics config is primary
    vim.diagnostic.config({ virtual_lines = false })
    local map = require("util.map").map
    map("n", "<leader>ul", function()
      local cur = vim.diagnostic.config().virtual_lines
      vim.diagnostic.config({ virtual_lines = not cur, virtual_text = cur })
    end, { desc = "Toggle lsp_lines" })
  end,
}
