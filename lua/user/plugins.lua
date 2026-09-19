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
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    cmd = "RenderMarkdown",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = {},
  },

  -- 3. UI niceties
  -- which-key: popup of available keybinds as you type a prefix. Surfaces our
  -- <leader> namespaces and makes prefix collisions visible instead of silent.
  -- Group labels below name the namespaces; the actual binds live in their
  -- usual files (keymaps.lua, telescope.lua, the LspAttach block in lsp.lua).
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)
      wk.add({
        { "<leader>b", group = "buffers" },
        { "<leader>c", group = "code (lsp + git)" },
        { "<leader>d", group = "diff (diffview)" },
        { "<leader>f", group = "find (telescope)" },
        { "<leader>l", group = "diagnostics" },
      })
    end,
  },
  { "nvim-lualine/lualine.nvim" },     -- statusline
  { "nvim-tree/nvim-web-devicons" },   -- icons (auto used by many plugins)
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
      stiffness = 0.8,
      damping = 0.95,
      -- Mask the target cursor by drawing over it instead of blanking
      -- 'guicursor'; a smear that ends early then cannot leave the real cursor
      -- invisible.
      hide_target_hack = true,
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
  -- Mini files (lazy: loaded on first require, which the <leader>e map in
  -- lua/user/keymaps.lua triggers)
  {
    "echasnovski/mini.files",
    version = false,
    lazy = true,
    config = function()
      require("mini.files").setup()
    end
  },
  -- Git gutter markers and change previews while editing.
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "┃" },
        change = { text = "┃" },
      },
      preview_config = { border = "rounded" },
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local function map(lhs, rhs, desc)
          vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc })
        end
        map("<leader>cn", function() gs.nav_hunk("next") end, "Next Git hunk")
        map("<leader>cp", function() gs.nav_hunk("prev") end, "Previous Git hunk")
        map("<leader>ch", gs.preview_hunk, "Preview Git hunk")
      end,
    },
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
