return {
  "MeanderingProgrammer/render-markdown.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  ft = { "markdown" },
  config = function()
    require("render-markdown").setup({
      heading = { enabled = true },
      code = { style = "normal" },
      bullet = { enabled = true },
      checkbox = { enabled = true },
      quote = { enabled = true },
    })
  end,
}
