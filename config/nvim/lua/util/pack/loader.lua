local M = {}

local function plugin_entry(spec)
  local src = spec[1] or spec.src
  if not src:match("^https?://") and not src:match("^git@") then
    src = "https://github.com/" .. src
  end
  return { src = src, version = spec.version }
end

-- Run a spec's config function (if any), protecting against errors.
local function run_config(spec)
  if type(spec.config) == "function" then
    local ok, err = pcall(spec.config)
    if not ok then
      vim.schedule(function()
        vim.notify(("pack: config for %s failed: %s"):format(spec.name, err), vim.log.levels.ERROR)
      end)
    end
  end
end

local function load_dependencies(spec)
  if type(spec.dependencies) ~= "table" then return end
  for _, dep in ipairs(spec.dependencies) do
    if type(dep) == "string" then
      dep = { dep }
    end
    if type(dep) == "table" then
      vim.pack.add({ plugin_entry(dep) }, { load = true })
      run_config({
        name = dep.name or (dep[1] or dep.src or "dependency"):match("([^/]+)%.git$") or (dep[1] or dep.src or "dependency"):match("([^/]+)$"),
        config = dep.config,
      })
    end
  end
end

-- Register a lazy spec to be loaded on an event/cmd/ft/key trigger.
function M.defer(spec)
  local group = vim.api.nvim_create_augroup("pack_" .. spec.name, { clear = true })

  local loaded = false
  local function load_now()
    if loaded then return end
    loaded = true
    load_dependencies(spec)
    vim.pack.add({ { src = spec.src, version = spec.version } }, { load = true })
    run_config(spec)
  end

  if spec.event then
    local events = type(spec.event) == "table" and spec.event or { spec.event }
    vim.api.nvim_create_autocmd(events, {
      group = group,
      once = true,
      callback = load_now,
    })
  end
  if spec.ft then
    local fts = type(spec.ft) == "table" and spec.ft or { spec.ft }
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = fts,
      once = true,
      callback = load_now,
    })
  end
  if spec.cmd then
    local cmds = type(spec.cmd) == "table" and spec.cmd or { spec.cmd }
    for _, c in ipairs(cmds) do
      -- The pattern may contain * for Dap* etc.
      if c:find("%*") then
        -- Register with a generic hook via CmdUndefined
        vim.api.nvim_create_autocmd("CmdUndefined", {
          group = group,
          pattern = c:gsub("%*", ".*"),
          callback = function()
            load_now()
          end,
        })
      else
        vim.api.nvim_create_user_command(c, function(args)
          pcall(vim.api.nvim_del_user_command, c)
          load_now()
          vim.cmd((c .. " %s"):format(args.args or ""))
        end, { nargs = "*" })
      end
    end
  end
  if spec.keys then
    for _, key in ipairs(spec.keys) do
      local lhs = type(key) == "table" and key[1] or key
      local mode = type(key) == "table" and (key.mode or "n") or "n"
      vim.keymap.set(mode, lhs, function()
        load_now()
        return lhs
      end, { expr = true, silent = true, desc = "Lazy-load " .. spec.name })
    end
  end
end

---@param spec table normalized spec
---@return boolean eager was loaded immediately
function M.register(spec)
  if not (spec.event or spec.ft or spec.cmd or spec.keys) then
    -- Eager
    load_dependencies(spec)
    vim.pack.add({ { src = spec.src, version = spec.version } }, { load = true })
    run_config(spec)
    return true
  end
  -- Install now but load on trigger
  vim.pack.add({ { src = spec.src, version = spec.version } }, { load = false })
  M.defer(spec)
  return false
end

return M
