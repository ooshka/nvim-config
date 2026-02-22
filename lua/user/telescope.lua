require("telescope").setup({})
local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>fh", function()
  require("telescope.builtin").find_files({
    hidden = true,
    no_ignore = true,
  })
end, { desc = "Find files (all, no ignore)" })
vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files (no hidden)"})
vim.keymap.set("n", "<leader>fg", builtin.live_grep,  { desc = "Live grep" })
vim.keymap.set("n", "<leader>fb", builtin.buffers,    { desc = "Buffers" })
vim.keymap.set("n", "<leader>ft", builtin.help_tags,  { desc = "Help tags" })

