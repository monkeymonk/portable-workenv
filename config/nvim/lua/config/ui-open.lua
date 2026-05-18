-- Route gx / vim.ui.open() through the host relay when the socket exists.
local sock = "/run/host-relay/open.sock"

if vim.uv.fs_stat(sock) then
  vim.ui.open = function(url)
    vim.system({ "xdg-open", url }, { detach = true })
    return { wait = function() end }
  end
end
