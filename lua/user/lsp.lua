-- lua/user/lsp.lua

-- mason: installer GUI for language servers
require("mason").setup()

-- mason-lspconfig: bridge Mason <-> lspconfig (v2.x: also auto-enables installed servers)
require("mason-lspconfig").setup({
  ensure_installed = {
    "lua_ls",                 -- Lua
    "jdtls",                  -- Java (launched/managed by nvim-jdtls, not enabled here)
    "kotlin_language_server", -- Kotlin
    -- Python: basedpyright is installed globally via npm (`npm i -g basedpyright`),
    -- not Mason -- its PyPI package is unreachable behind the corporate mirror.
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

-- Neovim 0.11+ ships default LSP maps under the `gr` prefix (grn/gra/grr/gri/grt).
-- They collide with our `gr` -> references map and make `gr` wait `timeoutlen`
-- before firing. Remove them so `gr` is instant; we provide our own below.
for _, lhs in ipairs({ "grn", "gra", "grr", "gri", "grt" }) do
  pcall(vim.keymap.del, { "n", "x" }, lhs)
end

-- Keymaps that only make sense when a language server is attached. Using a
-- single LspAttach autocmd means every server (current and future) gets these
-- automatically -- no need to wire up on_attach per server.
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("user_lsp_attach", { clear = true }),
  callback = function(event)
    local bufnr = event.buf
    local telescope = require("telescope.builtin")

    -- kotlin_language_server (fwcd) has a semantic-tokens bug that throws
    -- "Reached end of file before reaching line N" and spams the LSP log.
    -- Drop the capability so Neovim never requests semantic tokens from it;
    -- syntax highlighting falls back to treesitter, which is fine here.
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client.name == "kotlin_language_server" then
      client.server_capabilities.semanticTokensProvider = nil
    end
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = "LSP: " .. desc })
    end

    -- Code navigation (Telescope pickers handle multi-result jumps nicely)
    map("n", "gd", telescope.lsp_definitions,      "Go to definition")
    map("n", "gD", vim.lsp.buf.declaration,        "Go to declaration")
    map("n", "gr", telescope.lsp_references,       "References")
    map("n", "gi", telescope.lsp_implementations,  "Implementation")
    map("n", "gt", telescope.lsp_type_definitions, "Type definition")
    map("n", "<leader>cs", telescope.lsp_document_symbols, "Document symbols")

    -- Actions (all under the <leader>c "code" namespace so none of these
    -- buffer-local maps shadow a global prefix -- e.g. <leader>f finders or
    -- <leader>r reload -- which would stall them by timeoutlen when attached.)
    map("n", "K",  vim.lsp.buf.hover,               "Hover docs")
    map("n", "<leader>cr", vim.lsp.buf.rename,      "Rename symbol")
    map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
    map("n", "<leader>cf", function()
      vim.lsp.buf.format({ async = false })
    end, "Format buffer")
  end,
})

-- Capabilities: tell every server we support nvim-cmp completion.
-- The "*" config is merged into every server, so we set it once here.
vim.lsp.config("*", {
  capabilities = require("cmp_nvim_lsp").default_capabilities(),
})

-- Per-server settings (these merge on top of "*" and the bundled defaults)
vim.lsp.config("lua_ls", {
  settings = {
    Lua = { diagnostics = { globals = { "vim" } } },
  },
})

vim.lsp.config("ruby_lsp", {
  cmd = { "bundle", "exec", "ruby-lsp" },
  root_markers = { "Gemfile", ".git", ".ruby-version" },
})

-- basedpyright comes from a global npm install (not Mason), so resolve its
-- launcher from PATH. The Windows npm fallback is only valid on Windows/WSL;
-- on Unix an empty command would register a broken language server.
local basedpyright_cmd = vim.fn.exepath("basedpyright-langserver")
if basedpyright_cmd == "" and (vim.fn.has("win32") == 1 or vim.fn.has("wsl") == 1) then
  basedpyright_cmd = vim.fn.expand("$APPDATA/npm/basedpyright-langserver.cmd")
end

if basedpyright_cmd ~= "" then
  vim.lsp.config("basedpyright", {
    cmd = { basedpyright_cmd, "--stdio" },
    settings = {
      basedpyright = {
        analysis = {
          -- basedpyright defaults to the very strict "recommended"; "standard"
          -- matches pyright's behaviour. Bump to "recommended"/"strict" if wanted.
          typeCheckingMode = "standard",
          autoImportCompletions = true,
          diagnosticMode = "openFilesOnly",
        },
      },
    },
  })
end

vim.lsp.config("kotlin_language_server", {
  init_options = {
    -- Keep KLS cache state out of project roots and force init_options to be a
    -- JSON object; the server has crashed when it receives an empty array.
    storagePath = vim.fn.stdpath("cache") .. "/kotlin-language-server",
  },
})

-- Enable servers. mason-lspconfig v2 auto-enables the mason-managed ones, but
-- enabling explicitly is harmless and is required for ruby_lsp (not via mason).
vim.lsp.enable("lua_ls")
vim.lsp.enable("ruby_lsp")
if basedpyright_cmd ~= "" then
  vim.lsp.enable("basedpyright")
end
vim.lsp.enable("kotlin_language_server")

-- Java is handled by nvim-jdtls (see ftplugin/java.lua), which starts and
-- attaches its own client per project. Disable the generic jdtls autostart that
-- mason-lspconfig would otherwise trigger, to avoid two clients on one buffer.
vim.lsp.enable("jdtls", false)

-- Convenience commands. The classic :LspRestart / :LspLog are provided by the
-- old lspconfig *framework* module (require("lspconfig")), which we don't load
-- -- we use the native vim.lsp.config/enable API instead. Re-create them here.

-- :LspRestart [name]  -- stop matching clients, then re-attach by reloading the
-- buffers they were on. With no arg, restarts every active client.
vim.api.nvim_create_user_command("LspRestart", function(opts)
  local filter = opts.args ~= "" and { name = opts.args } or nil
  local clients = vim.lsp.get_clients(filter)
  if vim.tbl_isempty(clients) then
    vim.notify("LspRestart: no matching LSP clients", vim.log.levels.WARN)
    return
  end
  local bufs = {}
  for _, client in ipairs(clients) do
    for buf in pairs(client.attached_buffers or {}) do
      bufs[buf] = true
    end
    client:stop()
  end
  -- Give the servers a moment to exit, then reload each buffer to re-trigger
  -- filetype detection and the vim.lsp.enable autostart. Skip modified buffers
  -- (a reload would clobber unsaved changes); those reattach on next write.
  vim.defer_fn(function()
    for buf in pairs(bufs) do
      if vim.api.nvim_buf_is_valid(buf) and not vim.bo[buf].modified then
        vim.api.nvim_buf_call(buf, function()
          vim.cmd("edit")
        end)
      end
    end
  end, 1000)
end, { nargs = "?", desc = "Restart LSP client(s), optionally by name" })

-- :LspLog  -- open the LSP log file (~/.local/state/nvim/lsp.log)
vim.api.nvim_create_user_command("LspLog", function()
  vim.cmd.tabedit(vim.lsp.get_log_path())
end, { desc = "Open the LSP log file" })
