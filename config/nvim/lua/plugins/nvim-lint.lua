return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    local lint = require("lint")
    -- Linter map comes from config.tools (single source of truth).
    lint.linters_by_ft = require("config.tools").linters_by_ft

    local group = vim.api.nvim_create_augroup("workenv_lint", { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
      group = group,
      callback = function()
        lint.try_lint()
      end,
    })
  end,
}
