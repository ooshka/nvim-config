-- lua/user/options.lua
local o = vim.o
local wo = vim.wo
local bo = vim.bo
local opt = vim.opt  -- more ergonomic for list-like options

-- UI / editing
o.termguicolors = true
wo.number = true          -- line numbers
wo.relativenumber = true  -- relative line numbers
wo.cursorline = true      -- highlight current line
o.scrolloff = 4           -- keep 4 lines visible above/below cursor
o.signcolumn = "yes"
opt.fileformats = { "unix", "dos" }

-- Tabs / indent
opt.expandtab = true       -- use spaces instead of tabs
opt.shiftwidth = 2         -- indent size
opt.tabstop = 2            -- how wide a TAB feels
opt.smartindent = true

-- Search
o.ignorecase = true
o.smartcase = true        -- override ignorecase if search has caps
o.incsearch = true
o.hlsearch = true

-- Misc
o.clipboard = "unnamedplus"  -- use system clipboard
o.swapfile = false
o.undofile = true            -- persistent undo
opt.splitright = true
opt.splitbelow = true
opt.errorbells = false
opt.visualbell = false

-- WSL clipboard integration
vim.g.clipboard = {
  name = "win32yank",
  copy = {
    ["+"] = "win32yank.exe -i --crlf",
    ["*"] = "win32yank.exe -i --crlf",
  },
  paste = {
    ["+"] = "win32yank.exe -o --lf",
    ["*"] = "win32yank.exe -o --lf",
  },
  cache_enabled = 1,
}
