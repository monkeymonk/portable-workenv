-- workenv neovim entry point
vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- Load modules in order
require("config.options")
require("config.clipboard")
require("config.ui-open")
require("config.autocmds")
require("config.diagnostics")
require("config.keymaps")
require("config.pack")
