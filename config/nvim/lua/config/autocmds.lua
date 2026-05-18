local group = vim.api.nvim_create_augroup("workenv", { clear = true })

-- Highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  callback = function() vim.highlight.on_yank({ timeout = 200 }) end,
})

-- Resize splits on window resize
vim.api.nvim_create_autocmd("VimResized", {
  group = group,
  command = "tabdo wincmd =",
})

-- Last cursor position
vim.api.nvim_create_autocmd("BufReadPost", {
  group = group,
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local lcount = vim.api.nvim_buf_line_count(args.buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Auto-create missing parent dirs on save
vim.api.nvim_create_autocmd("BufWritePre", {
  group = group,
  callback = function(args)
    if args.match:match("^%w%w+:[\\/][\\/]") then return end
    local dir = vim.fn.fnamemodify(args.match, ":p:h")
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end
  end,
})
