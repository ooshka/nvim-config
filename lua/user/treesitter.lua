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
}

require("nvim-treesitter").install(ensure_installed)

vim.api.nvim_create_autocmd("FileType", {
  pattern = ensure_installed,
  callback = function()
    vim.treesitter.start()
    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})
