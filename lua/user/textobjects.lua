-- Syntax-aware selections, motions, and argument swaps powered by Treesitter.
local select = require("nvim-treesitter-textobjects.select")
local move = require("nvim-treesitter-textobjects.move")
local swap = require("nvim-treesitter-textobjects.swap")

require("nvim-treesitter-textobjects").setup({
  select = {
    lookahead = true,
    selection_modes = {
      ["@parameter.outer"] = "v",
      ["@function.outer"] = "V",
      ["@class.outer"] = "V",
    },
  },
  move = {
    set_jumps = true,
  },
})

local map = vim.keymap.set
local select_modes = { "x", "o" }
local move_modes = { "n", "x", "o" }

local function textobject(lhs, query, desc)
  map(select_modes, lhs, function()
    select.select_textobject(query, "textobjects")
  end, { desc = desc })
end

textobject("af", "@function.outer", "Around function")
textobject("if", "@function.inner", "Inside function")
textobject("ac", "@class.outer", "Around class")
textobject("ic", "@class.inner", "Inside class")
textobject("aa", "@parameter.outer", "Around argument")
textobject("ia", "@parameter.inner", "Inside argument")

local function jump(lhs, method, query, desc)
  map(move_modes, lhs, function()
    move[method](query, "textobjects")
  end, { desc = desc })
end

jump("]f", "goto_next_start", "@function.outer", "Next function")
jump("[f", "goto_previous_start", "@function.outer", "Previous function")
jump("]c", "goto_next_start", "@class.outer", "Next class")
jump("[c", "goto_previous_start", "@class.outer", "Previous class")
jump("]a", "goto_next_start", "@parameter.inner", "Next argument")
jump("[a", "goto_previous_start", "@parameter.inner", "Previous argument")

map("n", "<leader>cn", function()
  swap.swap_next("@parameter.inner")
end, { desc = "Swap argument with next" })

map("n", "<leader>cp", function()
  swap.swap_previous("@parameter.inner")
end, { desc = "Swap argument with previous" })
