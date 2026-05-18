return {
  "stevearc/conform.nvim",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    require("conform").setup({
      formatters_by_ft = {
        lua = { "stylua" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        javascriptreact = { "prettier" },
        css = { "prettier" },
        html = { "prettier" },
        json = { "prettier" },
        jsonc = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        go = { "goimports", "gofmt" },
        rust = { "rustfmt" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        zsh = { "shfmt" },
      },
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
