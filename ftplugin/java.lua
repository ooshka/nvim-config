-- ftplugin/java.lua
-- Runs every time a Java buffer is opened. nvim-jdtls starts (or attaches to an
-- existing) jdtls client scoped to the project root, which is the supported way
-- to run Java's language server -- the generic lspconfig/mason autostart for
-- jdtls is disabled in lua/user/lsp.lua to avoid a second client.
--
-- Requirements: a JDK 17+ on PATH (jdtls itself needs it to run), and the
-- `jdtls` package installed via Mason (it is in ensure_installed).

local ok, jdtls = pcall(require, "jdtls")
if not ok then
  return
end

-- Locate the Mason-installed jdtls launcher. mason.setup() prepends Mason's bin
-- dir to Neovim's PATH, so exepath resolves the platform wrapper (jdtls.cmd on
-- Windows, jdtls on unix).
local jdtls_cmd = vim.fn.exepath("jdtls")
if jdtls_cmd == "" then
  vim.notify("jdtls not found -- run :Mason and install 'jdtls'", vim.log.levels.WARN)
  return
end

-- Project root: prefer build-tool / VCS markers, fall back to cwd.
local root_markers = {
  "gradlew",
  "mvnw",
  "pom.xml",
  "build.gradle",
  "build.gradle.kts",
  "settings.gradle",
  ".git",
}
local root_dir = require("jdtls.setup").find_root(root_markers)
if not root_dir or root_dir == "" then
  root_dir = vim.fn.getcwd()
end

-- A unique workspace per project so jdtls doesn't mix indexes between projects.
local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. project_name

-- Tell jdtls the client supports its extended protocol (progress reports, class
-- file contents, build-config commands, etc.). Without this jdtls logs
-- "_java...command not supported on client" and the Gradle/Maven project import
-- degrades -- which leaves imports unresolved (red) and hover/definition dead.
local extended_caps = jdtls.extendedClientCapabilities
extended_caps.resolveAdditionalTextEditsSupport = true

local config = {
  cmd = { jdtls_cmd, "-data", workspace_dir },
  root_dir = root_dir,
  capabilities = require("cmp_nvim_lsp").default_capabilities(),
  init_options = {
    bundles = {},
    extendedClientCapabilities = extended_caps,
  },
  settings = {
    java = {
      signatureHelp = { enabled = true },
      contentProvider = { preferred = "fernflower" }, -- decompiler for libs
      -- Use the project's build tool to resolve the classpath.
      import = {
        gradle = { enabled = true, wrapper = { enabled = true } },
        maven = { enabled = true },
      },
      -- Prompt (rather than silently skip) when the build config changes.
      configuration = { updateBuildConfiguration = "interactive" },
      -- Surface an incomplete classpath as a warning instead of hard-failing.
      errors = { incompleteClasspath = { severity = "warning" } },
    },
  },
  -- Keymaps come from the global LspAttach autocmd in lua/user/lsp.lua, so they
  -- apply here automatically -- no on_attach needed.
}

jdtls.start_or_attach(config)
