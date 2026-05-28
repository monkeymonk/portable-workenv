-- Single source of truth for LSP servers, formatters, and linters, plus which
-- Mason packages to auto-install.
--
-- Entries with `needs_runtime` are CONFIGURED (so they activate the moment the
-- user installs the runtime + tool via mise/Mason) but are EXCLUDED from
-- out-of-the-box auto-install — their runtime is not baked into the image
-- (only Node is). This keeps the four consumers (lsp/mason/conform/nvim-lint)
-- from drifting out of sync, which is exactly the bug class this table prevents.

local M = {}

-- LSP servers: name -> { opts? = table, needs_runtime? = "go"|"rust"|... }
M.servers = {
  lua_ls = {
    opts = {
      settings = {
        Lua = {
          workspace = { checkThirdParty = false },
          telemetry = { enable = false },
          diagnostics = { globals = { "vim" } },
        },
      },
    },
  },
  ts_ls = {},
  tailwindcss = {},
  bashls = {},
  pyright = {},
  cssls = {},
  html = {},
  jsonls = {},
  yamlls = {},
  dockerls = {},
  docker_compose_language_service = {},
  emmet_ls = {
    opts = {
      filetypes = { "html", "css", "sass", "scss", "less", "javascriptreact", "typescriptreact" },
    },
  },
  gopls = { needs_runtime = "go" },
  rust_analyzer = { needs_runtime = "rust" },
}

-- Mason formatter/linter packages: name -> { needs_runtime? }.
M.tools = {
  stylua = {},
  prettier = {},
  shfmt = {},
  shellcheck = {},
  markdownlint = {},
  yamllint = {},
  eslint_d = {},
  goimports = { needs_runtime = "go" },
}

M.formatters_by_ft = {
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
}

M.linters_by_ft = {
  javascript = { "eslint_d" },
  typescript = { "eslint_d" },
  typescriptreact = { "eslint_d" },
  javascriptreact = { "eslint_d" },
  markdown = { "markdownlint" },
  yaml = { "yamllint" },
  sh = { "shellcheck" },
  bash = { "shellcheck" },
}

local function installable(set)
  local out = {}
  for name, t in pairs(set) do
    if not t.needs_runtime then
      out[#out + 1] = name
    end
  end
  table.sort(out)
  return out
end

-- LSP servers to auto-install OOTB (runtime baked / standalone binary).
function M.lsp_ensure_installed()
  return installable(M.servers)
end

-- Mason formatter/linter packages to auto-install OOTB.
function M.tool_ensure_installed()
  return installable(M.tools)
end

return M
