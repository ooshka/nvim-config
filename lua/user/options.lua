-- lua/user/options.lua
local o = vim.o
local wo = vim.wo
local opt = vim.opt  -- more ergonomic for list-like options

-- UI / editing
o.termguicolors = true
wo.number = true          -- line numbers
wo.relativenumber = true  -- relative line numbers
wo.cursorline = true      -- highlight current line
o.scrolloff = 4           -- keep 4 lines visible above/below cursor
o.signcolumn = "yes"

-- Set explicitly rather than relying on the default: smear-cursor.nvim appends
-- its hide entry to this option, and can only strip that entry again when there
-- is already a preceding entry to separate it from.
opt.guicursor = {
  "n-v-c-sm:block-blinkwait500-blinkon500-blinkoff500",
  "i-ci-ve:ver25-blinkwait500-blinkon500-blinkoff500",
  "r-cr-o:hor20-blinkwait500-blinkon500-blinkoff500",
}
opt.fileformats = { "unix", "dos" }

-- Tabs / indent
opt.expandtab = true       -- use spaces instead of tabs
opt.shiftwidth = 4         -- indent size
opt.tabstop = 4            -- how wide a TAB feels
opt.softtabstop = 4        -- spaces inserted when pressing TAB
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

-- clipboard integration
if vim.fn.has("wsl") == 1 then
  vim.g.clipboard = {
    name = "win32yank-wsl",
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
elseif vim.fn.has("mac") == 1 then
  vim.g.clipboard = {
    name = "macOS-clipboard",
    copy = {
      ["+"] = "pbcopy",
      ["*"] = "pbcopy",
    },
    paste = {
      ["+"] = "pbpaste",
      ["*"] = "pbpaste",
    },
    cache_enabled = 1,
  }
end
