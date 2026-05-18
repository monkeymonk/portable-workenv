-- Plugin registration entry point.
-- Each file under lua/plugins/ returns a spec table (or list of spec tables).
local pack = require("util.pack")

local all_specs = {}

local plugin_dir = vim.fn.stdpath("config") .. "/lua/plugins"
if vim.fn.isdirectory(plugin_dir) == 1 then
  for _, file in ipairs(vim.fn.readdir(plugin_dir)) do
    if file:match("%.lua$") then
      local mod_name = "plugins." .. file:gsub("%.lua$", "")
      local ok, mod = pcall(require, mod_name)
      if ok and mod then
        if type(mod) == "table" and mod[1] and type(mod[1]) == "table" then
          -- List of specs
          for _, s in ipairs(mod) do
            table.insert(all_specs, s)
          end
        else
          table.insert(all_specs, mod)
        end
      elseif not ok then
        vim.schedule(function()
          vim.notify(("pack: failed to load " .. mod_name .. ": " .. tostring(mod)), vim.log.levels.ERROR)
        end)
      end
    end
  end
end

pack.add(all_specs)
