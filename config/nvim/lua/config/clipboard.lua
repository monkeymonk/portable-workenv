local relay_sock = "/run/host-relay/open.sock"

local function system(cmd, input)
  local out = vim.fn.system(cmd, input)
  return vim.v.shell_error == 0, out
end

local function relay_available()
  return vim.fn.executable("socat") == 1 and vim.uv.fs_stat(relay_sock) ~= nil
end

local function relay_copy(lines)
  local text = table.concat(lines, "\n")
  local ok, encoded = system({ "base64", "-w", "0" }, text)
  if not ok then
    vim.notify("workenv clipboard: base64 encode failed", vim.log.levels.WARN)
    return
  end
  ok = system({ "socat", "-", "UNIX-CONNECT:" .. relay_sock }, "clipboard-set " .. encoded .. "\n")
  if not ok then
    vim.notify("workenv clipboard: host relay copy failed", vim.log.levels.WARN)
  end
end

local function relay_paste()
  local ok, encoded = system({ "socat", "-", "UNIX-CONNECT:" .. relay_sock }, "clipboard-get\n")
  if not ok or encoded == "" then
    return { {}, "v" }
  end
  local decoded_ok, text = system({ "base64", "-d" }, encoded)
  if not decoded_ok then
    vim.notify("workenv clipboard: base64 decode failed", vim.log.levels.WARN)
    return { {}, "v" }
  end
  text = text:gsub("\n$", "")
  return { vim.split(text, "\n", { plain = true }), "v" }
end

if relay_available() then
  vim.g.clipboard = {
    name = "workenv host relay",
    copy = {
      ["+"] = relay_copy,
      ["*"] = relay_copy,
    },
    paste = {
      ["+"] = relay_paste,
      ["*"] = relay_paste,
    },
  }
else
  local osc52 = require("vim.ui.clipboard.osc52")

  -- OSC 52 copy works when the host terminal permits clipboard escape
  -- sequences. OSC 52 paste requires a terminal response and commonly times
  -- out, so paste is intentionally disabled unless the host relay is mounted.
  vim.g.clipboard = {
    name = "OSC 52 copy-only",
    copy = {
      ["+"] = osc52.copy("+"),
      ["*"] = osc52.copy("*"),
    },
    paste = {
      ["+"] = function() return { {}, "v" } end,
      ["*"] = function() return { {}, "v" } end,
    },
  }
end
