require("nvim-tree").setup({})
vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "Toggle file tree" })
vim.keymap.set("n", "<leader>o", ":NvimTreeFocus<CR>", { desc = "Focus file tree" })

