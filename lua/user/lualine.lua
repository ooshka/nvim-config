-- A server counts as busy from the moment it reports an LspProgress token
-- until that token reports done. Not every server reports progress, so the
-- color function also treats any client with an outstanding unanswered
-- request as busy.
local busy_clients = {}

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
    return { fg = "#e06c75" } -- red: no client attached
  end
  for _, client in ipairs(clients) do
    if busy_clients[client.id] or not vim.tbl_isempty(client.requests) then
      return { fg = "#e5c07b" } -- yellow: attached, work in progress
    end
  end
  return { fg = "#98c379" } -- green: attached, idle
end

require("lualine").setup({
  options = {
    theme = "auto",
    icons_enabled = true,
  },
  sections = {
    lualine_x = { { function() return "●" end, color = lsp_status_color }, "encoding", "fileformat", "filetype" },
  },
})

