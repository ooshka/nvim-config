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

-- Jumplist navigation (mirrors h/l: gh = back/left, gl = forward/right).
-- These sit alongside the g-prefixed LSP nav (gd/gr/gi/gt). gl maps to the
-- built-in <C-i> via noremap, so our <Tab>=bnext below doesn't shadow it.
map("n", "gh", "<C-o>", { desc = "Jump back (older location)" })
map("n", "gl", "<C-i>", { desc = "Jump forward (newer location)" })

-- Buffer swapping
map("n", "<Tab>", "<cmd>bnext<CR>", { desc = "Next Buffer" })
map("n", "<S-Tab>", "<cmd>bprevious<CR>", { desc = "Previous Buffer" })
map("n", "<leader>b", "<cmd>bdelete<CR>", { desc = "Delete Buffer" })
map("n", "<leader>r", function()
  vim.cmd("edit!")
end, { desc = "Reload Buffer" })

-- File explorer (mini.files). The require triggers lazy.nvim to load + setup
-- the plugin on first use; the spec in plugins.lua is marked lazy accordingly.
map("n", "<leader>e", function()
  require("mini.files").open()
end, { desc = "File explorer (mini.files)" })

-- Clear search highlight
map("n", "<leader>h", "<cmd>nohlsearch<cr>", { desc = "Clear highlight" })

-- Diagnostic float (built-in LSP)
map("n", "gL", vim.diagnostic.open_float, { desc = "Line diagnostics" })
map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = "Prev diagnostic" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "Next diagnostic" })
map("n", "<leader>ld", function ()
    vim.diagnostic.reset(nil,0)
  end, { desc = "Prompt diagnostic lint" }
)

-- Diffview (side-by-side review against a base ref) --

-- origin/HEAD resolves to e.g. "origin/main"; fall back to local main/master.
local function default_base()
  local ref = vim.fn.systemlist("git rev-parse --abbrev-ref origin/HEAD 2>/dev/null")[1]
  if vim.v.shell_error == 0 and ref and ref ~= "" then
    return ref
  end
  return "main"
end

-- triple-dot: show what HEAD changed since its merge-base with <base>.
local function diffview_open(base)
  vim.cmd("DiffviewOpen " .. base .. "...HEAD")
end

map("n", "<leader>dd", function() diffview_open(default_base()) end,
  { desc = "Diffview: review vs default branch" })
map("n", "<leader>dD", function()
  vim.ui.input({ prompt = "Diff against ref: ", default = default_base() }, function(ref)
    if ref and ref ~= "" then diffview_open(ref) end
  end)
end, { desc = "Diffview: review vs ref…" })
map("n", "<leader>dh", "<cmd>DiffviewFileHistory<cr>", { desc = "Diffview: branch file history" })
map("n", "<leader>df", "<cmd>DiffviewFileHistory %<cr>", { desc = "Diffview: current file history" })
map("n", "<leader>dc", "<cmd>DiffviewClose<cr>", { desc = "Diffview: close" })

-- Terminal --

local term = require("user.terminal")

map("n", "<leader>1", term.toggle_float, { desc = "Terminal (float scratch)" })
map("n", "<leader>2", term.toggle_bottom_2, { desc = "Terminal #2 (bottom)" })
map("n", "<leader>3", term.toggle_bottom_3, { desc = "Terminal #3 (bottom)" })

-- Terminal-mode: Esc just exits terminal insert mode
map("t", "<Esc>", [[<C-\><C-n>]], { noremap = true, silent = true, desc = "Exit terminal mode" })
