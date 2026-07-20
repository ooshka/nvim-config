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
local function listed_buffers()
  return vim.tbl_filter(function(buf)
    return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted
  end, vim.api.nvim_list_bufs())
end

local function close_buffers(bufs)
  if #bufs == 0 then
    return
  end

  local current = vim.api.nvim_get_current_buf()
  local target = {}
  for _, buf in ipairs(bufs) do
    if buf ~= current then
      target[#target + 1] = buf
    end
  end

  if #target == 0 then
    return
  end

  local has_modified = false
  for _, buf in ipairs(target) do
    if vim.bo[buf].modified then
      has_modified = true
      break
    end
  end

  local cmd = has_modified and "confirm bdelete" or "bdelete"
  for _, buf in ipairs(target) do
    vim.cmd(string.format("%s %d", cmd, buf))
  end

  if vim.api.nvim_buf_is_valid(current) and vim.bo[current].buflisted then
    return
  end

  for _, buf in ipairs(listed_buffers()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      vim.api.nvim_set_current_buf(buf)
      return
    end
  end

  vim.cmd("enew")
end

local function close_all_buffers()
  close_buffers(listed_buffers())
end

local function close_other_buffers()
  local current = vim.api.nvim_get_current_buf()
  local bufs = listed_buffers()
  local others = {}
  for _, buf in ipairs(bufs) do
    if buf ~= current then
      others[#others + 1] = buf
    end
  end
  close_buffers(others)
end

map("n", "<Tab>", "<cmd>bnext<CR>", { desc = "Next Buffer" })
map("n", "<S-Tab>", "<cmd>bprevious<CR>", { desc = "Previous Buffer" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete Buffer" })
map("n", "<leader>bo", close_other_buffers, { desc = "Delete Other Buffers" })
map("n", "<leader>bD", close_all_buffers, { desc = "Delete All Buffers" })
map("n", "<leader>r", function()
  vim.cmd("edit!")
end, { desc = "Reload Buffer" })

-- File explorer (mini.files). The require triggers lazy.nvim to load + setup
-- the plugin on first use; the spec in plugins.lua is marked lazy accordingly.
-- <leader>e reveals the current file in its directory; falls back to cwd for
-- unnamed/scratch buffers. <leader>E always opens at the cwd root.
map("n", "<leader>e", function()
  local buf = vim.api.nvim_buf_get_name(0)
  if buf ~= "" and vim.fn.filereadable(buf) == 1 then
    require("mini.files").open(buf)
  else
    require("mini.files").open()
  end
end, { desc = "File explorer at current file" })
map("n", "<leader>E", function()
  require("mini.files").open()
end, { desc = "File explorer at cwd" })

-- Clear search highlight
map("n", "<leader>h", "<cmd>nohlsearch<cr>", { desc = "Clear highlight" })

-- Delete without replacing the default register.
map({ "n", "x" }, "<leader>x", [["_d]], { desc = "Delete to black hole register" })

-- Copy buffer paths to the system clipboard (+ register).
-- <leader>yn = just the file name; <leader>yp = path from the repo root.
map("n", "<leader>yn", function()
  local name = vim.fn.expand("%:t")
  if name == "" then
    vim.notify("No file name for this buffer", vim.log.levels.WARN)
    return
  end
  vim.fn.setreg("+", name)
  vim.notify("Copied: " .. name)
end, { desc = "Copy file name" })

map("n", "<leader>yp", function()
  local file = vim.fn.expand("%:p")
  if file == "" then
    vim.notify("No file name for this buffer", vim.log.levels.WARN)
    return
  end
  local root = vim.fn.systemlist("git -C " .. vim.fn.fnameescape(vim.fn.expand("%:p:h")) ..
    " rev-parse --show-toplevel 2>/dev/null")[1]
  local rel
  if vim.v.shell_error == 0 and root and root ~= "" then
    rel = file:sub(#root + 2) -- strip "<root>/"
  else
    rel = vim.fn.fnamemodify(file, ":.") -- fall back to cwd-relative
  end
  vim.fn.setreg("+", rel)
  vim.notify("Copied: " .. rel)
end, { desc = "Copy repo-relative path" })

-- which-key: show the keymaps active in the current buffer (incl. LSP binds)
map("n", "<leader>?", function()
  require("which-key").show({ global = false })
end, { desc = "Buffer-local keymaps (which-key)" })

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
