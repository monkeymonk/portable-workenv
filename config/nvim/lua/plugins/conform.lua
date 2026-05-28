return {
  "stevearc/conform.nvim",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    require("conform").setup({
      -- Formatter map comes from config.tools (single source of truth). go/rust
      -- entries are skipped automatically until their toolchain is installed
      -- (not baked in); conform no-ops on missing tools.
      formatters_by_ft = require("config.tools").formatters_by_ft,
      format_on_save = function(bufnr)
        local ft = vim.bo[bufnr].filetype
        if ft == "markdown" or ft == "gitcommit" then return nil end
        return { timeout_ms = 2000, lsp_fallback = true }
      end,
    })
    local map = require("util.map").map
    map({ "n", "v" }, "<leader>cf", function()
      require("conform").format({ async = true, lsp_fallback = true })
    end, { desc = "Format" })
  end,
}
