-- lua/user/treesitter.lua
require("nvim-treesitter.configs").setup({
  ensure_installed = {
    "lua",
    "javascript",
    "typescript",
    "python",
    "bash",
    "json",
    "yaml",
    "markdown",
    "markdown_inline",
  },
  highlight = {
    enable = true,
  },
  indent = {
    enable = true,
  },
})

