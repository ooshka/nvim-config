-- lua/user/plugins.lua

-- Bootstrap lazy.nvim if it's not installed yet
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Tell lazy.nvim which plugins to install
require("lazy").setup({
  -- 1. LSP support (language servers, autocompletion, snippets)
  {
    "neovim/nvim-lspconfig",
  },
  {
    "williamboman/mason.nvim",          -- LSP/DAP/tool installer UI
    build = ":MasonUpdate",
  },
  {
    "williamboman/mason-lspconfig.nvim" -- Mason <-> lspconfig bridge
  },

  -- Autocompletion stack
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
  },

  -- 2. Treesitter (better syntax highlighting & text objects)
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
  },

  -- 3. UI niceties
  { "nvim-lualine/lualine.nvim" },     -- statusline
  { "kyazdani42/nvim-web-devicons" },  -- icons (auto used by many plugins)
  { "nvim-tree/nvim-tree.lua" },       -- file explorer
  { "nvim-telescope/telescope.nvim",   -- fuzzy finder
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  -- 4. Colorscheme   
  { 
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function ()
    	vim.cmd.colorscheme("catppuccin-mocha")
    end
  },
})

