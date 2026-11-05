-- lua/user/buffers.lua
local M = {}

local function listed_buffers()
  return vim.tbl_filter(function(buf)
    return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted
  end, vim.api.nvim_list_bufs())
end

local function close_buffers(bufs, keep_current)
  if #bufs == 0 then
    return
  end

  local current = vim.api.nvim_get_current_buf()
  local target = {}
  for _, buf in ipairs(bufs) do
    if not keep_current or buf ~= current then
      target[#target + 1] = buf
    end
  end

  if #target == 0 then
    return
  end

  local has_modified = false
  for _, buf in ipairs(target) do
    if vim.bo[buf].modified then
      has_modified = true
      break
    end
  end

  local cmd = has_modified and "confirm bdelete" or "bdelete"
  if not keep_current and vim.tbl_contains(target, current) then
    local replacement = vim.api.nvim_create_buf(false, false)
    vim.cmd(string.format("confirm buffer %d", replacement))
    if vim.api.nvim_get_current_buf() == current then
      vim.api.nvim_buf_delete(replacement, { force = true })
      return
    end
    vim.bo[replacement].buflisted = true
  end

  for _, buf in ipairs(target) do
    vim.cmd(string.format("%s %d", cmd, buf))
  end

  if vim.api.nvim_buf_is_valid(current) and vim.bo[current].buflisted then
    return
  end

  for _, buf in ipairs(listed_buffers()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      vim.api.nvim_set_current_buf(buf)
      return
    end
  end

  vim.cmd("enew")
end

function M.close_all()
  close_buffers(listed_buffers(), false)
end

function M.close_others()
  close_buffers(listed_buffers(), true)
end

function M.close_side(side)
  local current = vim.api.nvim_get_current_buf()
  local bufs = listed_buffers()
  local current_index
  for index, buf in ipairs(bufs) do
    if buf == current then
      current_index = index
      break
    end
  end

  if not current_index then
    return
  end

  local targets = {}
  local first = side == "left" and 1 or current_index + 1
  local last = side == "left" and current_index - 1 or #bufs
  for index = first, last do
    targets[#targets + 1] = bufs[index]
  end
  close_buffers(targets, true)
end

return M
