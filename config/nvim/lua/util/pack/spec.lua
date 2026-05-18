local M = {}

---@param spec table|string
---@return table normalized
function M.normalize(spec)
  if type(spec) == "string" then
    spec = { spec }
  end
  local src = spec[1] or spec.src
  assert(src, "pack spec missing source")
  -- Github shorthand: "user/repo" -> full URL
  if not src:match("^https?://") and not src:match("^git@") then
    src = "https://github.com/" .. src
  end
  local name = spec.name or src:match("([^/]+)%.git$") or src:match("([^/]+)$")
  name = name:gsub("%.git$", "")
  return {
    src = src,
    name = name,
    version = spec.version,
    event = spec.event,
    ft = spec.ft,
    cmd = spec.cmd,
    keys = spec.keys,
    priority = spec.priority,
    dependencies = spec.dependencies,
    config = spec.config,
  }
end

return M
