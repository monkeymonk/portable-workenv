-- Global LSP setup. Called from plugins/mason.lua after mason-lspconfig.
-- Server list + opts come from config.tools (single source of truth). Servers
-- with needs_runtime (gopls/rust_analyzer) are configured here too — enabling a
-- server with no installed binary is a quiet no-op, so they auto-activate once
-- the user installs the runtime + server.
local map = require("util.map").map
local tools = require("config.tools")

for name, spec in pairs(tools.servers) do
  vim.lsp.config(name, spec.opts or {})
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
    map("n", "<leader>cr", vim.lsp.buf.rename, opts("Rename"))
    map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts("Code action"))
    -- K (hover) is owned by lspsaga (plugins/lspsaga.lua); <leader>cf (format)
    -- is owned by conform (plugins/conform.lua). Don't redefine them here.
  end,
})
