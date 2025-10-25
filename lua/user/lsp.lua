-- lua/user/lsp.lua

-- mason: installer GUI for language servers
require("mason").setup()

-- mason-lspconfig: bridge Mason <-> lspconfig
require("mason-lspconfig").setup({
  ensure_installed = {
    "lua_ls",     -- Lua
    "tsserver",   -- TypeScript / JavaScript
    "pyright",    -- Python
    -- add more languages you care about
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

  map("n", "gd", vim.lsp.buf.definition,       "Go to definition")
  map("n", "gr", vim.lsp.buf.references,       "References")
  map("n", "gi", vim.lsp.buf.implementation,   "Implementation")
  map("n", "K",  vim.lsp.buf.hover,            "Hover docs")
  map("n", "<leader>rn", vim.lsp.buf.rename,   "Rename symbol")
  map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
  map("n", "<leader>f", function()
    vim.lsp.buf.format({ async = false })
  end, "Format buffer")
end

-- Capabilities: tell LSP we support completion
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Setup each server with lspconfig
local lspconfig = require("lspconfig")
local servers = { "lua_ls", "tsserver", "pyright" }

for _, server in ipairs(servers) do
  local opts = {
    on_attach = on_attach,
    capabilities = capabilities,
  }

  -- Per-server tweaks:
  if server == "lua_ls" then
    opts.settings = {
      Lua = {
        diagnostics = {
          globals = { "vim" }, -- stop "vim is undefined" warning
        },
      },
    }
  end

  lspconfig[server].setup(opts)
end
-- lua/user/lsp.lua

-- mason: installer GUI for language servers
require("mason").setup()

-- mason-lspconfig: bridge Mason <-> lspconfig
require("mason-lspconfig").setup({
  ensure_installed = {
    "lua_ls",     -- Lua
    "tsserver",   -- TypeScript / JavaScript
    "pyright",    -- Python
    -- add more languages you care about
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

  map("n", "gd", vim.lsp.buf.definition,       "Go to definition")
  map("n", "gr", vim.lsp.buf.references,       "References")
  map("n", "gi", vim.lsp.buf.implementation,   "Implementation")
  map("n", "K",  vim.lsp.buf.hover,            "Hover docs")
  map("n", "<leader>rn", vim.lsp.buf.rename,   "Rename symbol")
  map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
  map("n", "<leader>f", function()
    vim.lsp.buf.format({ async = false })
  end, "Format buffer")
end

-- Capabilities: tell LSP we support completion
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Setup each server with lspconfig
local lspconfig = require("lspconfig")
local servers = { "lua_ls", "tsserver", "pyright" }

for _, server in ipairs(servers) do
  local opts = {
    on_attach = on_attach,
    capabilities = capabilities,
  }

  -- Per-server tweaks:
  if server == "lua_ls" then
    opts.settings = {
      Lua = {
        diagnostics = {
          globals = { "vim" }, -- stop "vim is undefined" warning
        },
      },
    }
  end

  lspconfig[server].setup(opts)
end

