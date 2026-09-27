require("telescope").setup({})
local builtin = require("telescope.builtin")
local map = vim.keymap.set

map("n", "<leader>ff", function()
  builtin.find_files({ hidden = true })
end, { desc = "Find files" })
map("n", "<leader>fg", function()
  builtin.live_grep({ additional_args = { "--hidden" } })
end, { desc = "Live grep" })
-- Escape hatch: also include gitignored files (node_modules, build output, …)
map("n", "<leader>fh", function()
  builtin.find_files({ hidden = true, no_ignore = true })
end, { desc = "Find files (all, no ignore)" })
map("n", "<leader>fH", function()
  builtin.live_grep({ additional_args = { "--hidden", "--no-ignore" } })
end, { desc = "Live grep (all, no ignore)" })
map("n", "<leader>fb", builtin.buffers,     { desc = "Buffers" })
map("n", "<leader>ft", builtin.help_tags,   { desc = "Help tags" })
map("n", "<leader>fk", builtin.keymaps,     { desc = "Keymaps" })
map("n", "<leader>fr", builtin.resume,      { desc = "Resume last picker" })
map("n", "<leader>fd", builtin.diagnostics, { desc = "Workspace diagnostics" })
map("n", "<leader>fs", builtin.lsp_workspace_symbols, { desc = "Workspace symbols" })
map("n", "<leader>fo", builtin.oldfiles,    { desc = "Recent files" })
map("n", "<leader>fw", builtin.grep_string, { desc = "Grep word under cursor" })
map("n", "<leader>f/", builtin.current_buffer_fuzzy_find, { desc = "Search current buffer" })
map("n", "<leader>fc", builtin.git_status,  { desc = "Git changed files" })

map("x", "<leader>fw", function()
  local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), {
    type = vim.fn.mode(),
  })
  local selection = table.concat(lines, "\n")
  if selection ~= "" then
    builtin.grep_string({ search = selection })
  end
end, { desc = "Grep selection" })
