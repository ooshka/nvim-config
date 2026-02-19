-- lua/user/keymaps.lua
local map = vim.keymap.set

-- Fast saving / quitting
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit window" })

-- Better window movement
map("n", "<C-h>", "<C-w>h", { desc = "Left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Down window" })
map("n", "<C-k>", "<C-w>k", { desc = "Up window" })
map("n", "<C-l>", "<C-w>l", { desc = "Right window" })

-- Buffer swapping
map("n", "<Tab>", "<cmd>bnext<CR>", { desc = "Next Buffer" })
map("n", "<S-Tab>", "<cmd>bprevious<CR>", { desc = "Previous Buffer" })
map("n", "<leader>b", "<cmd>bdelete<CR>", { desc = "Delete Buffer" })
-- Clear search highlight
map("n", "<leader>h", "<cmd>nohlsearch<cr>", { desc = "Clear highlight" })

-- Diagnostic float (built-in LSP)
map("n", "gl", vim.diagnostic.open_float, { desc = "Line diagnostics" })
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "<leader>ld", function ()
    vim.diagnostic.reset(nil,0)
  end, { desc = "Prompt diagnostic lint" }
)

-- Terminal --

local term = require("user.terminal")

vim.keymap.set("n", "<leader>1", term.toggle_float, { desc = "Terminal (float scratch)" })

vim.keymap.set("n", "<leader>2", term.toggle_bottom_2, { desc = "Terminal #2 (bottom)" })
vim.keymap.set("n", "<leader>3", term.toggle_bottom_3, { desc = "Terminal #3 (bottom)" })

vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })

-- 1) Terminal-mode: Esc just exits terminal insert mode
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { noremap = true, silent = true, desc = "Exit terminal mode" })
