-- init.lua
require("user.options")
require("user.keymaps")
require("user.plugins")  -- sets up plugin manager + plugins
require("user.lsp")
require("user.treesitter")

vim.o.backgroun = "dark"
vim.cmd.colorscheme("gruvbox")

vim.opt.errorbells = false
vim.opt.visualbell = false
vim.opt.t_vb = ""
