local o = vim.opt

-- UI
o.number = true
o.relativenumber = true
o.signcolumn = "yes"
o.cursorline = true
o.scrolloff = 8
o.sidescrolloff = 8
o.wrap = false
o.termguicolors = true
o.showmode = false
o.pumheight = 10
o.splitright = true
o.splitbelow = true

-- Editing
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.smartindent = true
o.breakindent = true

-- Search
o.ignorecase = true
o.smartcase = true
o.grepprg = "rg --vimgrep --smart-case --hidden"
o.grepformat = "%f:%l:%c:%m"

-- Clipboard
o.clipboard = "unnamedplus"

-- Files
o.swapfile = false
o.undofile = true
o.confirm = true
o.updatetime = 250
o.timeoutlen = 400

-- Folding (set up for treesitter later)
o.foldlevel = 99
o.foldmethod = "expr"
o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
o.foldtext = ""

-- Completion
o.completeopt = "menu,menuone,noselect"

-- Wildignore
o.wildignore:append({ "*/node_modules/*", "*/.git/*", "*/dist/*" })
