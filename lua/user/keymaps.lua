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

-- Codex --
vim.keymap.set("n", "<leader>cc", function()
  local buf = vim.api.nvim_create_buf(false, true)
  local width  = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = "rounded",
  })
  vim.fn.termopen("codex")
end, { desc = "Open Codex AI assistant" })

-- Terminal --

local term = require("user.terminal")

vim.keymap.set("n", "<leader>1", term.toggle_float, { desc = "Terminal (float scratch)" })

vim.keymap.set("n", "<leader>2", term.toggle_bottom_2, { desc = "Terminal #2 (bottom)" })
vim.keymap.set("n", "<leader>3", term.toggle_bottom_3, { desc = "Terminal #3 (bottom)" })

vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })

-- 1) Terminal-mode: Esc just exits terminal insert mode
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { noremap = true, silent = true, desc = "Exit terminal mode" })

-- 2) For ToggleTerm terminals only: in NORMAL mode, Esc closes/minimizes *this* terminal
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function(ev)
    -- ToggleTerm sets this buffer variable for its terminals
    if vim.b[ev.buf].toggle_number ~= nil then
      vim.keymap.set("n", "<Esc>", function()
        local ok, toggleterm = pcall(require, "toggleterm")
        if not ok then return end
        toggleterm.toggle(vim.b.toggle_number) -- toggle THIS terminal by its ID
      end, { buffer = ev.buf, noremap = true, silent = true, desc = "Minimize this ToggleTerm" })
    end
  end,
})

