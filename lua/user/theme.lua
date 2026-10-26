-- Palette entrypoint. Keep this table aligned with theme-lab/themes/nova.json;
-- the highlight mapping below is destination-specific and remains stable.
local nova = {
  background = "#1A1F2D", foreground = "#C8D0E0", cursor = "#80C8E0",
  selection = "#283247", black = "#111521", red = "#B86068",
  green = "#58AD9E", yellow = "#C8A860", blue = "#6F9FC8",
  purple = "#B0A0D8", cyan = "#78B8B0", white = "#9AA4B8",
  bright_black = "#586478", bright_red = "#D0909C",
  bright_green = "#7AC8B6", bright_yellow = "#D4B878",
  bright_blue = "#84BCE2", bright_purple = "#B0A0D8",
  bright_cyan = "#72D0CF", bright_white = "#DCE4F0",
}

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
vim.g.colors_name = "nova"
vim.o.background = "dark"

local set = vim.api.nvim_set_hl
local function link(name, target) set(0, name, { link = target }) end

local highlights = {
  Normal = { fg = nova.foreground, bg = "NONE" },
  NormalNC = { fg = nova.foreground, bg = "NONE" },
  NormalFloat = { fg = nova.foreground, bg = nova.background },
  FloatBorder = { fg = nova.bright_black, bg = nova.background },
  Cursor = { fg = nova.background, bg = nova.cursor },
  CursorLine = { bg = nova.black },
  CursorLineNr = { fg = nova.bright_yellow, bg = nova.black, bold = true },
  LineNr = { fg = nova.bright_black },
  SignColumn = { bg = "NONE" },
  Visual = { bg = nova.selection },
  Search = { fg = nova.background, bg = nova.yellow },
  MatchParen = { fg = nova.bright_cyan, bold = true, underline = true },
  WinSeparator = { fg = nova.bright_black },
  Pmenu = { fg = nova.foreground, bg = nova.background },
  PmenuSel = { fg = nova.bright_white, bg = nova.selection, bold = true },
  StatusLine = { fg = nova.foreground, bg = nova.selection },
  StatusLineNC = { fg = nova.white, bg = nova.black },
  TabLine = { fg = nova.white, bg = nova.black },
  TabLineFill = { fg = nova.bright_black, bg = nova.black },
  TabLineSel = { fg = nova.bright_white, bg = nova.selection, bold = true },
  Directory = { fg = nova.blue },
  Title = { fg = nova.bright_blue, bold = true },
  NonText = { fg = nova.bright_black },
  Comment = { fg = nova.bright_black, italic = true },
  Constant = { fg = nova.cyan },
  String = { fg = nova.green },
  Character = { fg = nova.bright_green },
  Number = { fg = nova.yellow },
  Boolean = { fg = nova.yellow, bold = true },
  Identifier = { fg = nova.foreground },
  Function = { fg = nova.blue },
  Statement = { fg = nova.purple },
  Operator = { fg = nova.cyan },
  Keyword = { fg = nova.purple },
  Exception = { fg = nova.red },
  PreProc = { fg = nova.cyan },
  Type = { fg = nova.yellow },
  Special = { fg = nova.cyan },
  Delimiter = { fg = nova.white },
  Error = { fg = nova.bright_red, bold = true },
  Todo = { fg = nova.background, bg = nova.yellow, bold = true },
  DiagnosticError = { fg = nova.red },
  DiagnosticWarn = { fg = nova.yellow },
  DiagnosticInfo = { fg = nova.blue },
  DiagnosticHint = { fg = nova.cyan },
  GitSignsAdd = { fg = nova.green },
  GitSignsChange = { fg = nova.yellow },
  GitSignsDelete = { fg = nova.red },
  MiniFilesDirectory = { fg = nova.blue },
}
for name, value in pairs(highlights) do set(0, name, value) end

local links = {
  ["@comment"] = "Comment", ["@string"] = "String",
  ["@string.escape"] = "Special", ["@character"] = "Character",
  ["@number"] = "Number", ["@number.float"] = "Number",
  ["@boolean"] = "Boolean", ["@constant"] = "Constant",
  ["@variable"] = "Identifier", ["@function"] = "Function",
  ["@function.call"] = "Function", ["@constructor"] = "Type",
  ["@keyword"] = "Keyword", ["@keyword.function"] = "Keyword",
  ["@keyword.operator"] = "Keyword", ["@keyword.return"] = "Keyword",
  ["@operator"] = "Operator", ["@type"] = "Type",
  ["@attribute"] = "PreProc", ["@property"] = "Identifier",
  ["@punctuation.delimiter"] = "Delimiter", ["@punctuation.bracket"] = "Delimiter",
}
for name, target in pairs(links) do link(name, target) end
set(0, "@constant.builtin", { fg = nova.cyan, bold = true })
set(0, "@variable.builtin", { fg = nova.red })
set(0, "@variable.parameter", { fg = nova.foreground, italic = true })
set(0, "@variable.member", { fg = nova.cyan })
set(0, "@function.builtin", { fg = nova.bright_blue })
set(0, "@function.method", { fg = nova.blue })
set(0, "@type.builtin", { fg = nova.bright_yellow })

local headings = {
  nova.bright_blue, nova.bright_purple, nova.bright_cyan,
  nova.bright_green, nova.bright_yellow, nova.bright_red,
}
for level, color in ipairs(headings) do
  set(0, "@markup.heading." .. level .. ".markdown", { fg = color, bold = true })
  set(0, "RenderMarkdownH" .. level, { fg = color, bold = true })
  set(0, "RenderMarkdownH" .. level .. "Bg", { fg = color, bold = true })
end
set(0, "@markup.raw", { fg = nova.green })
set(0, "@markup.link", { fg = nova.blue, underline = true })
set(0, "@markup.link.url", { fg = nova.bright_black, underline = true })
set(0, "@markup.list", { fg = nova.purple })
set(0, "@markup.quote", { fg = nova.white, italic = true })
set(0, "RenderMarkdownCode", { bg = nova.black })
set(0, "RenderMarkdownCodeInline", { fg = nova.green, bg = nova.black })
link("RenderMarkdownCodeBorder", "RenderMarkdownCode")
link("RenderMarkdownCodeFallback", "RenderMarkdownCode")

local terminal = {
  nova.black, nova.red, nova.green, nova.yellow, nova.blue, nova.purple,
  nova.cyan, nova.white, nova.bright_black, nova.bright_red, nova.bright_green,
  nova.bright_yellow, nova.bright_blue, nova.bright_purple, nova.bright_cyan,
  nova.bright_white,
}
for index, color in ipairs(terminal) do
  vim.g["terminal_color_" .. (index - 1)] = color
end

return nova
