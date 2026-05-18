local M = {}

function M.check()
  vim.health.start("pack")

  -- Check vim.pack availability
  if vim.pack and vim.pack.add then
    vim.health.ok("vim.pack.add available")
  else
    vim.health.error("vim.pack.add not available (requires Neovim 0.12+)")
    return
  end

  -- List installed plugins from pack dirs
  local data = vim.fn.stdpath("data")
  local pack_dir = data .. "/site/pack"
  local stat = vim.uv.fs_stat(pack_dir)
  if not stat then
    vim.health.warn("No pack directory found at " .. pack_dir)
    return
  end

  local count = 0
  for group_name, group_type in vim.fs.dir(pack_dir) do
    if group_type == "directory" then
      for _, sub in ipairs({ "start", "opt" }) do
        local sub_path = pack_dir .. "/" .. group_name .. "/" .. sub
        local sub_stat = vim.uv.fs_stat(sub_path)
        if sub_stat then
          for plugin_name, plugin_type in vim.fs.dir(sub_path) do
            if plugin_type == "directory" then
              vim.health.ok(("%s/%s/%s"):format(group_name, sub, plugin_name))
              count = count + 1
            end
          end
        end
      end
    end
  end

  if count == 0 then
    vim.health.warn("No plugins found in pack directory")
  else
    vim.health.info(count .. " plugins installed")
  end
end

return M
