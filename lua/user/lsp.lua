-- lua/user/lsp.lua

-- mason: installer GUI for language servers
require("mason").setup()

-- mason-lspconfig: bridge Mason <-> lspconfig
require("mason-lspconfig").setup({
  ensure_installed = {
    "lua_ls",  -- Lua
  },
  automatic_installation = true,
})

-- nvim-cmp (completion) setup
local cmp = require("cmp")
local luasnip = require("luasnip")

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }), -- enter to accept
    ["<Tab>"] = function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end,
    ["<S-Tab>"] = function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end,
  }),
  sources = {
    { name = "nvim_lsp" },
    { name = "luasnip"  },
  },
})

-- Attach function: set keymaps that need an active LSP
local on_attach = function(_, bufnr)
  local map = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
  end

  map("n", "gd", vim.lsp.buf.definition,          "Go to definition")
  map("n", "gr", vim.lsp.buf.references,          "References")
  map("n", "gi", vim.lsp.buf.implementation,      "Implementation")
  map("n", "K",  vim.lsp.buf.hover,               "Hover docs")
  map("n", "<leader>rn", vim.lsp.buf.rename,      "Rename symbol")
  map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
  map("n", "<leader>f", function()
    vim.lsp.buf.format({ async = false })
  end, "Format buffer")
end

-- Capabilities: tell LSP we support completion
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Define Server Configs
vim.lsp.config["lua_ls"] = {
  on_attach = on_attach,
  capabilities = capabilities,
  settings = {
    Lua = {
      diagnostics = {
        globals = { "vim" },
      },
    },
  },
}

vim.lsp.config["ruby_lsp"] = {
  on_attach = on_attach,
  capabilities = capabilities,
  cmd = { "bundle", "exec", "ruby-lsp" },
  root_dir = require("lspconfig.util").root_pattern("Gemfile", ".git"),
}

-- Enable Servers
vim.lsp.enable("lua_ls")
vim.lsp.enable("ruby_lsp")

