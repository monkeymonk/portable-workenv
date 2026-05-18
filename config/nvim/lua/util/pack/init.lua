local spec_mod = require("util.pack.spec")
local loader = require("util.pack.loader")

local M = {}

---@param specs table[]
function M.add(specs)
  -- Normalize and sort by priority (highest first for eager)
  local normalized = {}
  for _, s in ipairs(specs) do
    table.insert(normalized, spec_mod.normalize(s))
  end
  table.sort(normalized, function(a, b)
    return (a.priority or 0) > (b.priority or 0)
  end)
  for _, s in ipairs(normalized) do
    loader.register(s)
  end
end

return M
