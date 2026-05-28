-- workenv core: route gx / vim.ui.open() through the host relay.
--
-- Core (kernel) layer — see clipboard.lua for the loading model. Opt out with:
--   vim.g.workenv_core_open = false

if vim.g.workenv_core_open == false then
  return
end

local sock = "/run/host-relay/open.sock"

if vim.uv.fs_stat(sock) then
  vim.ui.open = function(url)
    vim.system({ "xdg-open", url }, { detach = true })
    return { wait = function() end }
  end
end
