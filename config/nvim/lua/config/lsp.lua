-- Global LSP setup. Called from plugins/mason.lua after mason-lspconfig.
local map = require("util.map").map

local servers = {
  lua_ls = {
    settings = {
      Lua = {
        workspace = { checkThirdParty = false },
        telemetry = { enable = false },
        diagnostics = { globals = { "vim" } },
      },
    },
  },
  ts_ls = {},
  tailwindcss = {},
  gopls = {},
  rust_analyzer = {},
  bashls = {},
  pyright = {},
  cssls = {},
  html = {},
  jsonls = {},
  yamlls = {},
  dockerls = {},
  docker_compose_language_service = {},
  emmet_ls = {
    filetypes = { "html", "css", "sass", "scss", "less", "javascriptreact", "typescriptreact" },
  },
}

for name, opts in pairs(servers) do
  vim.lsp.config(name, opts)
  vim.lsp.enable(name)
end

-- Keymaps on attach
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("workenv_lsp_attach", { clear = true }),
  callback = function(args)
    local bufnr = args.buf
    local opts = function(desc) return { buffer = bufnr, desc = desc } end
    map("n", "gd", vim.lsp.buf.definition, opts("Go to definition"))
    map("n", "gD", vim.lsp.buf.declaration, opts("Go to declaration"))
    map("n", "gi", vim.lsp.buf.implementation, opts("Go to implementation"))
    map("n", "gr", vim.lsp.buf.references, opts("Find references"))
    map("n", "K", vim.lsp.buf.hover, opts("Hover"))
    map("n", "<leader>cr", vim.lsp.buf.rename, opts("Rename"))
    map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts("Code action"))
    map("n", "<leader>cf", function() vim.lsp.buf.format({ async = true }) end, opts("Format"))
  end,
})
