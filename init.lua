-- init.lua
require("user.options")
require("user.keymaps")
require("user.plugins")  -- sets up plugin manager + plugins
require("user.lsp")
require("user.treesitter")
require("user.lualine")
require("user.nvim-tree")
require("user.telescope")

vim.o.background = "dark"
vim.cmd.colorscheme("gruvbox")
