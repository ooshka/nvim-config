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

return M
