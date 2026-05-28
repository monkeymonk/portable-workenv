-- workenv neovim entry point
vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- Host integration (clipboard relay, gx/open routing) lives in the baked
-- "core" layer at /opt/workenv/nvim-core (loaded via the nvim wrapper's
-- packpath injection), so it applies to any config — see share/nvim-core/.
-- Load modules in order
require("config.options")
require("config.autocmds")
require("config.diagnostics")
require("config.keymaps")
require("config.pack")

-- Local tweak seam — optional user module, loaded last so it can override the
-- above. Create lua/config/user.lua in the volume (gitignored, survives
-- rebuilds). For a full replacement use --config nvim=<path> instead.
pcall(require, "config.user")
