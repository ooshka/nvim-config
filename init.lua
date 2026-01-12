-- init.lua

vim.g.mapleader = " " -- <Space> is leader

require("user.options")
require("user.plugins") -- sets up plugin manager + plugins
require("user.lsp")
require("user.treesitter")
require("user.lualine")
require("user.nvim-tree")
require("user.telescope")
require("user.terminal")
require("user.keymaps")
