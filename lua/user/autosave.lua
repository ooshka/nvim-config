local M = {}

local function buffer_path(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return nil
  end

  return vim.fs.normalize(name)
end

function M.is_enabled(bufnr)
  bufnr = bufnr or 0
  local path = buffer_path(bufnr)
  if not path then
    return false
  end

  return vim.fs.root(path, ".git") ~= nil
end

local function save(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr)
    or not vim.api.nvim_buf_get_option(bufnr, "modified")
    or not vim.api.nvim_buf_get_option(bufnr, "modifiable")
    or vim.api.nvim_buf_get_option(bufnr, "readonly")
    or vim.api.nvim_buf_get_option(bufnr, "buftype") ~= ""
    or not M.is_enabled(bufnr)
  then
    return
  end

  local ok, err = pcall(vim.api.nvim_buf_call, bufnr, function()
    vim.cmd("silent update")
  end)
  if not ok then
    vim.notify("Autosave failed: " .. err, vim.log.levels.WARN)
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("GitRepoAutosave", { clear = true })
  vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "BufLeave", "FocusLost" }, {
    group = group,
    desc = "Save modified file buffers inside Git worktrees",
    callback = function(args)
      save(args.buf)
    end,
  })
end

return M
