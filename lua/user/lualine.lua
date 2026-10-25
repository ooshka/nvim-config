-- A server counts as busy from the moment it reports an LspProgress token
-- until that token reports done. Not every server reports progress, so the
-- color function also treats any client with an outstanding unanswered
-- request as busy.
local busy_clients = {}
local nova = require("user.theme")

local lualine_theme = {
  normal = {
    a = { fg = nova.background, bg = nova.blue, gui = "bold" },
    b = { fg = nova.foreground, bg = nova.selection },
    c = { fg = nova.foreground, bg = nova.background },
  },
  insert = { a = { fg = nova.background, bg = nova.green, gui = "bold" } },
  visual = { a = { fg = nova.background, bg = nova.purple, gui = "bold" } },
  replace = { a = { fg = nova.background, bg = nova.red, gui = "bold" } },
  command = { a = { fg = nova.background, bg = nova.yellow, gui = "bold" } },
  inactive = {
    a = { fg = nova.foreground, bg = nova.background },
    b = { fg = nova.foreground, bg = nova.background },
    c = { fg = nova.foreground, bg = nova.background },
  },
}

vim.api.nvim_create_autocmd("LspProgress", {
  callback = function(args)
    local client_id = args.data.client_id
    local done = args.data.params.value.kind == "end"
    if done then
      busy_clients[client_id] = nil
    else
      busy_clients[client_id] = true
    end
  end,
})

local function lsp_status_color()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if vim.tbl_isempty(clients) then
    return { fg = nova.red } -- no client attached
  end
  for _, client in ipairs(clients) do
    if busy_clients[client.id] or not vim.tbl_isempty(client.requests) then
      return { fg = nova.yellow } -- attached, work in progress
    end
  end
  return { fg = nova.green } -- attached, idle
end

local function autosave_status()
  if require("user.autosave").is_enabled(0) then
    return ""
  end

  return ""
end

require("lualine").setup({
  options = {
    theme = lualine_theme,
    icons_enabled = true,
  },
  sections = {
    lualine_x = {
      { autosave_status, color = { fg = nova.green } },
      { function() return "●" end, color = lsp_status_color },
      "encoding",
      "fileformat",
      "filetype",
    },
  },
})
