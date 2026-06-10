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
  {
    "mfussenegger/nvim-jdtls", -- Java: richer jdtls setup (see ftplugin/java.lua)
    ft = "java",
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
    branch = "master", -- classic, stable API (the `main` branch is a different, fast-moving rewrite)
    build = ":TSUpdate",
  },

  -- 3. UI niceties
  { "nvim-lualine/lualine.nvim" },     -- statusline
  { "kyazdani42/nvim-web-devicons" },  -- icons (auto used by many plugins)
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
    -- Smooth window scroll
  {
    "karb94/neoscroll.nvim",
    opts = {
      mappings = { "<C-u>", "<C-d>", "<C-b>", "<C-f>", "zz", "zt", "zb" },
      easing = "circular",
      duration_multiplier = 1.0,
    },
  },

  -- Cursor animation effect
  {
    "sphamba/smear-cursor.nvim",
    opts = {
      smear_between_neighbor_lines = true,
      smear_insert_mode = true,
      -- optional tuning:
      stiffness = 0.8,
      damping = 0.95,
    },
  },
  -- Terminal access
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
	      shade_terminals = false,
        start_in_insert = true,
      })
    end
  },
  -- Buffer tabs
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = "nvim-tree/nvim-web-devicons",
    config = function()
      require("bufferline").setup {}
    end
  },
  -- Mini files
  {
    "echasnovski/mini.files",
    version = false,
    config = function()
      require("mini.files").setup()
      vim.keymap.set("n", "<leader>e", function()
        require("mini.files").open()
      end)
    end
  },
  -- Diffview: side-by-side code review (changelist sidebar + diff in main panel).
  -- Keymaps live in lua/user/keymaps.lua (<leader>d*). Lazy-loaded on its commands.
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = {
      "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles",
      "DiffviewFocusFiles", "DiffviewFileHistory", "DiffviewRefresh",
    },
    config = function()
      local actions = require("diffview.actions")
      -- Diffview's defaults shadow our global <leader>b (close buffer) and
      -- <leader>e (mini.files) with its file-panel toggle/focus. Move those onto
      -- the <leader>d diff namespace, and make the bare <leader>b/<leader>e a
      -- no-op *inside* diffview so the reflex isn't hijacked (and so it doesn't
      -- fall through to bdelete on diffview's special buffers). Outside diffview
      -- — including files opened with `gf` — the globals are untouched.
      local panel_keys = {
        { "n", "<leader>b",  function() end,        { desc = "(no-op in Diffview — use <leader>dt)" } },
        { "n", "<leader>e",  function() end,        { desc = "(no-op in Diffview — use <leader>de)" } },
        { "n", "<leader>dt", actions.toggle_files,  { desc = "Diffview: toggle file panel" } },
        { "n", "<leader>de", actions.focus_files,   { desc = "Diffview: focus file panel" } },
      }
      require("diffview").setup({
        enhanced_diff_hl = true,          -- richer intra-line (word-level) highlighting
        -- Default layout is diff2_horizontal = side-by-side, which is what we want.
        keymaps = {
          view = panel_keys,
          file_panel = panel_keys,
          file_history_panel = panel_keys,
        },
      })
    end
  },
})

