-- lua/user/treesitter.lua
local ensure_installed = {
  "lua",
  "javascript",
  "typescript",
  "python",
  "java",
  "kotlin",
  "bash",
  "json",
  "ruby",
  "yaml",
  "markdown",
  "markdown_inline",
  "terraform",
  "hcl",
}

require("nvim-treesitter").install(ensure_installed)

-- Neovim gives *.tfvars its own filetype, but the grammar is the same one.
vim.treesitter.language.register("terraform", "terraform-vars")

local highlight_filetypes = vim.list_extend(vim.deepcopy(ensure_installed), { "terraform-vars" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = highlight_filetypes,
  callback = function()
    vim.treesitter.start()
    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})
