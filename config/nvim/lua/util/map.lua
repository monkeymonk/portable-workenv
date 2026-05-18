local M = {}

---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param opts? table
function M.map(mode, lhs, rhs, opts)
  opts = opts or {}
  opts.silent = opts.silent ~= false
  vim.keymap.set(mode, lhs, rhs, opts)
end

return M
