local Terminal = require("toggleterm.terminal").Terminal

-- Floating "scratch" terminal (quick commands)
local float_term = Terminal:new({
  id = 1,
  direction = "float",
  hidden = true,
})

-- Bottom "work" terminals (more permanent)
local bottom_term_2 = Terminal:new({
  id = 2,
  direction = "horizontal",
  hidden = true,
  -- size can be number or function
  size = 15,
})

local bottom_term_3 = Terminal:new({
  id = 3,
  direction = "horizontal",
  hidden = true,
  size = 15,
})

local quick_agents = {
  claude = {
    command = "claude",
    args = { "--model", "haiku", "--permission-mode", "plan" },
  },
  codex = {
    command = "codex",
    args = { "--model", "gpt-5.6-luna", "--sandbox", "read-only" },
  },
}

local quick_term

local function project_root()
  local file = vim.api.nvim_buf_get_name(0)
  local start = file ~= "" and file or vim.fn.getcwd()
  return vim.fs.root(start, ".git") or (file ~= "" and vim.fs.dirname(file)) or vim.fn.getcwd()
end

local function selected_agent()
  -- Match Hive's default: trim/lowercase the environment value and use Claude
  -- when it is unset or blank.
  local name = vim.trim(vim.env.HIVE_AGENT_DEFAULT or ""):lower()
  if name == "" then
    name = "claude"
  end

  local agent = quick_agents[name]
  if not agent then
    vim.notify(
      string.format("Invalid HIVE_AGENT_DEFAULT=%q; expected codex or claude", name),
      vim.log.levels.ERROR
    )
    return nil
  end
  return name, agent
end

local function quick_agent_terminal()
  if quick_term then
    return quick_term
  end

  local name, agent = selected_agent()
  if not agent then
    return nil
  end

  local command = vim.o.shell
  if vim.fn.executable(agent.command) == 1 then
    local parts = { vim.fn.shellescape(agent.command) }
    for _, arg in ipairs(agent.args) do
      parts[#parts + 1] = vim.fn.shellescape(arg)
    end
    command = table.concat(parts, " ")
  else
    vim.notify(
      string.format("%s is selected, but `%s` is not on PATH; opening a shell", name, agent.command),
      vim.log.levels.WARN
    )
  end

  quick_term = Terminal:new({
    id = 4,
    cmd = command,
    dir = project_root(),
    direction = "float",
    display_name = "Quick agent (" .. name .. ")",
    hidden = true,
  })
  return quick_term
end

local function context_lines(use_selection)
  local buffer = vim.api.nvim_get_current_buf()
  local line_count = vim.api.nvim_buf_line_count(buffer)
  local first
  local last

  if use_selection then
    first = vim.fn.line("v")
    last = vim.fn.line(".")
    if first > last then
      first, last = last, first
    end
  else
    local cursor = vim.api.nvim_win_get_cursor(0)[1]
    first = math.max(1, cursor - 10)
    last = math.min(line_count, cursor + 10)
  end

  return first, last, vim.api.nvim_buf_get_lines(buffer, first - 1, last, false)
end

-- Helpers you can map
local M = {}

function M.toggle_float()
  float_term:toggle()
end

function M.toggle_bottom_2()
  bottom_term_2:toggle()
end

function M.toggle_bottom_3()
  bottom_term_3:toggle()
end

function M.toggle_quick_agent()
  local term = quick_agent_terminal()
  if term then
    term:toggle()
  end
end

function M.fresh_quick_agent()
  if quick_term then
    quick_term:shutdown()
    quick_term = nil
  end
  M.toggle_quick_agent()
end

function M.copy_context(use_selection)
  local file = vim.api.nvim_buf_get_name(0)
  local root = project_root()
  local label = file ~= "" and (vim.fs.relpath(root, file) or file) or "[No Name]"
  local first, last, lines = context_lines(use_selection)
  local filetype = vim.bo.filetype ~= "" and vim.bo.filetype or "text"
  local location = first == last and tostring(first) or string.format("%d-%d", first, last)
  local context = table.concat({
    string.format("File: %s:%s", label, location),
    "Filetype: " .. filetype,
    "",
    "````" .. filetype,
    table.concat(lines, "\n"),
    "````",
  }, "\n")

  vim.fn.setreg("+", context)
  vim.notify(string.format("Copied agent context: %s:%s", label, location))
  M.toggle_quick_agent()
end

return M
