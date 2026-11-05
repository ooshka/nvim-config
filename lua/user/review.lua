-- lua/user/review.lua
--
-- Inline PR review notes. Comments live in <repo>/pr_review/dev_review.md as
-- entries of the form:
--
--   ## path/from/repo/root.lua:42-48
--   <!-- review-id: 1a2b3c sha: 990f9ab -->
--
--   Comment body (markdown).
--
-- The header is `gF`-compatible and is the only anchor, so other tools (or an
-- agent writing its own review in the same format) interoperate with the
-- parser. The review file is the single source of truth: signs, navigation and
-- the quickfix list are all derived from it on demand.

local M = {}

local REVIEW_REL = "pr_review/dev_review.md"
local ns = vim.api.nvim_create_namespace("user_review")
local flash_ns = vim.api.nvim_create_namespace("user_review_flash")

vim.api.nvim_set_hl(0, "ReviewSign", { link = "DiagnosticInfo", default = true })
vim.api.nvim_set_hl(0, "ReviewRange", { link = "NonText", default = true })

-- Paths and git ------------------------------------------------------------

local function git_root(path)
  return vim.fs.root(path ~= "" and path or vim.fn.getcwd(), ".git")
end

local function review_file(root)
  return root .. "/" .. REVIEW_REL
end

-- Returns root and repo-relative path for a buffer, or nil for buffers that
-- are not files inside a git repository (or are the review file itself).
local function buf_location(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" or vim.bo[buf].buftype ~= "" then
    return nil
  end
  name = vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
  local root = git_root(name)
  if not root then
    return nil
  end
  root = vim.fs.normalize(root)
  local rel = name:sub(#root + 2)
  if rel == REVIEW_REL then
    return nil
  end
  return root, rel
end

local function head_sha(root)
  local out = vim.system({ "git", "-C", root, "rev-parse", "--short", "HEAD" }, { text = true }):wait()
  return out.code == 0 and vim.trim(out.stdout) or nil
end

-- Parsing and serialising ----------------------------------------------------

local HEADER = "^## (%S+):(%d+)%-?(%d*)%s*$"
local META = "^<!%-%- review%-id: (%w+)(.-)%-%->%s*$"

local function trim_blank_edges(lines)
  local first, last = 1, #lines
  while first <= last and vim.trim(lines[first]) == "" do first = first + 1 end
  while last >= first and vim.trim(lines[last]) == "" do last = last - 1 end
  return vim.list_slice(lines, first, last)
end

local function new_id(entries)
  local taken = {}
  for _, e in ipairs(entries) do taken[e.id] = true end
  local id
  repeat
    id = string.format("%06x", (vim.uv.hrtime() + math.random(0, 0xffffff)) % 0x1000000)
  until not taken[id]
  return id
end

-- Parsed results are cached per file and invalidated by mtime/size.
local cache = {}

local function parse(lines)
  local doc = { preamble = {}, entries = {} }
  local current
  for i, line in ipairs(lines) do
    local path, first, last = line:match(HEADER)
    if path then
      current = {
        path = path,
        first = tonumber(first),
        last = tonumber(last ~= "" and last or first),
        body = {},
        line = i,
      }
      table.insert(doc.entries, current)
    elseif current and #current.body == 0 and not current.id and line:match(META) then
      local id, rest = line:match(META)
      current.id = id
      current.sha = rest:match("sha: (%w+)")
    elseif current then
      table.insert(current.body, line)
    else
      table.insert(doc.preamble, line)
    end
  end
  for _, e in ipairs(doc.entries) do
    e.body = trim_blank_edges(e.body)
    e.id = e.id or new_id(doc.entries)
  end
  return doc
end

local function load(root)
  local file = review_file(root)
  local stat = vim.uv.fs_stat(file)
  if not stat then
    return { preamble = { "# Dev review", "" }, entries = {} }
  end
  local c = cache[file]
  if c and c.mtime == stat.mtime.sec and c.nsec == stat.mtime.nsec and c.size == stat.size then
    return c.doc
  end
  local doc = parse(vim.fn.readfile(file))
  cache[file] = { mtime = stat.mtime.sec, nsec = stat.mtime.nsec, size = stat.size, doc = doc }
  return doc
end

local function range_text(e)
  return e.first == e.last and tostring(e.first) or (e.first .. "-" .. e.last)
end

local function save(root, doc)
  local out = vim.deepcopy(trim_blank_edges(doc.preamble))
  if #out > 0 then table.insert(out, "") end
  for _, e in ipairs(doc.entries) do
    table.insert(out, string.format("## %s:%s", e.path, range_text(e)))
    table.insert(out, string.format("<!-- review-id: %s%s -->", e.id, e.sha and (" sha: " .. e.sha) or ""))
    table.insert(out, "")
    vim.list_extend(out, e.body)
    table.insert(out, "")
  end
  local file = review_file(root)
  vim.fn.mkdir(vim.fs.dirname(file), "p")
  vim.fn.writefile(out, file)
  cache[file] = nil
  -- Keep an open buffer of the review file in step with the disk.
  local rbuf = vim.fn.bufnr(file)
  if rbuf ~= -1 and vim.api.nvim_buf_is_loaded(rbuf) and not vim.bo[rbuf].modified then
    vim.api.nvim_buf_call(rbuf, function() vim.cmd("checktime") end)
  end
end

local function entries_for(root, rel)
  local list = {}
  for _, e in ipairs(load(root).entries) do
    if e.path == rel then table.insert(list, e) end
  end
  table.sort(list, function(a, b) return a.first < b.first end)
  return list
end

local function entries_at(root, rel, lnum)
  return vim.tbl_filter(function(e)
    return e.first <= lnum and lnum <= e.last
  end, entries_for(root, rel))
end

-- Signs ----------------------------------------------------------------------

function M.refresh(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_loaded(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local root, rel = buf_location(buf)
  if not root then return end
  local count = vim.api.nvim_buf_line_count(buf)
  for _, e in ipairs(entries_for(root, rel)) do
    for l = e.first, math.min(e.last, count) do
      vim.api.nvim_buf_set_extmark(buf, ns, l - 1, 0, {
        sign_text = l == e.first and "\u{f075}" or "│",
        sign_hl_group = l == e.first and "ReviewSign" or "ReviewRange",
        priority = 20,
      })
    end
  end
end

local function refresh_all()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    M.refresh(buf)
  end
end

-- Comment float ----------------------------------------------------------------

local function close_float(win)
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

-- Deletes the entry with `id` from the review file.
local function delete_entry(root, id)
  local doc = load(root)
  for i, e in ipairs(doc.entries) do
    if e.id == id then
      table.remove(doc.entries, i)
      save(root, doc)
      refresh_all()
      vim.notify("Review comment deleted")
      return
    end
  end
end

-- Opens an editor float for `target` ({ root, path, first, last, id? }).
-- Closing the float or `:w` writes the entry into the review file; an empty
-- body removes the entry.
local function open_editor(target)
  local existing
  if target.id then
    for _, e in ipairs(load(target.root).entries) do
      if e.id == target.id then existing = e end
    end
  end

  local name = "review://" .. target.path .. ":" .. range_text(target) .. (target.id and ("#" .. target.id) or "#new")
  local stale = vim.fn.bufnr(name)
  if stale ~= -1 then vim.api.nvim_buf_delete(stale, { force = true }) end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, name)
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  if existing then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, existing.body)
  end
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modified = false

  local width = math.min(90, vim.o.columns - 6)
  local height = math.min(12, vim.o.lines - 6)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = string.format(" %s:%s ", target.path, range_text(target)),
    title_pos = "center",
    footer = " q/<Esc> save & close · <leader>md delete ",
    footer_pos = "center",
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true

  local id = target.id
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      local body = trim_blank_edges(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
      local doc = load(target.root)
      local idx
      for i, e in ipairs(doc.entries) do
        if id and e.id == id then idx = i end
      end
      if #body == 0 then
        if idx then delete_entry(target.root, id) end
        id = nil
      else
        if idx then
          doc.entries[idx].body = body
        else
          id = new_id(doc.entries)
          table.insert(doc.entries, {
            id = id,
            path = target.path,
            first = target.first,
            last = target.last,
            sha = head_sha(target.root),
            body = body,
          })
        end
        save(target.root, doc)
        vim.notify("Review comment saved")
      end
      vim.bo[buf].modified = false
      refresh_all()
    end,
  })

  local function save_and_close()
    if vim.bo[buf].modified then vim.cmd("write") end
    close_float(win)
  end
  local function delete_and_close()
    if id then delete_entry(target.root, id) end
    vim.bo[buf].modified = false
    close_float(win)
  end
  vim.keymap.set("n", "q", save_and_close, { buffer = buf, desc = "Save and close review comment" })
  vim.keymap.set("n", "<Esc>", save_and_close, { buffer = buf, desc = "Save and close review comment" })
  vim.keymap.set("n", "<leader>md", delete_and_close, { buffer = buf, desc = "Delete review comment" })

  if not existing then
    vim.cmd("startinsert")
  end
end

local function pick(entries, prompt, cb)
  if #entries == 1 then return cb(entries[1]) end
  vim.ui.select(entries, {
    prompt = prompt,
    format_item = function(e)
      return string.format("%s  %s", range_text(e), e.body[1] or "")
    end,
  }, function(choice)
    if choice then cb(choice) end
  end)
end

local function current_location()
  local root, rel = buf_location(0)
  if not root then
    vim.notify("Review comments need a file inside a git repository", vim.log.levels.WARN)
  end
  return root, rel
end

-- Normal mode: edit the comment(s) covering the cursor line, or start a new
-- comment on that line.
function M.comment_line()
  local root, rel = current_location()
  if not root then return end
  local lnum = vim.fn.line(".")
  local hits = entries_at(root, rel, lnum)
  if #hits == 0 then
    return open_editor({ root = root, path = rel, first = lnum, last = lnum })
  end
  pick(hits, "Edit review comment", function(e)
    open_editor({ root = root, path = rel, first = e.first, last = e.last, id = e.id })
  end)
end

-- Visual mode: always start a new comment on the selected range.
function M.comment_range()
  local root, rel = current_location()
  local first, last = vim.fn.line("v"), vim.fn.line(".")
  if first > last then first, last = last, first end
  vim.cmd("normal! \27")
  if not root then return end
  open_editor({ root = root, path = rel, first = first, last = last })
end

function M.delete()
  local root, rel = current_location()
  if not root then return end
  local hits = entries_at(root, rel, vim.fn.line("."))
  if #hits == 0 then
    vim.notify("No review comment on this line")
    return
  end
  pick(hits, "Delete review comment", function(e) delete_entry(root, e.id) end)
end

function M.preview()
  local root, rel = current_location()
  if not root then return end
  local hits = entries_at(root, rel, vim.fn.line("."))
  if #hits == 0 then
    vim.notify("No review comment on this line")
    return
  end
  local lines = {}
  for i, e in ipairs(hits) do
    if i > 1 then vim.list_extend(lines, { "", "---", "" }) end
    table.insert(lines, string.format("**%s:%s**", rel, range_text(e)))
    table.insert(lines, "")
    vim.list_extend(lines, e.body)
  end
  vim.lsp.util.open_floating_preview(lines, "markdown", { border = "rounded", max_width = 90, focus_id = "user_review" })
end

-- direction: 1 for next, -1 for previous. Wraps around the file and previews
-- the comment landed on.
function M.jump(direction)
  local root, rel = buf_location(0)
  if not root then return end
  local list = entries_for(root, rel)
  if #list == 0 then
    vim.notify("No review comments in this file")
    return
  end
  local lnum = vim.fn.line(".")
  local target
  if direction > 0 then
    for _, e in ipairs(list) do
      if e.first > lnum then target = e break end
    end
    target = target or list[1]
  else
    for i = #list, 1, -1 do
      if list[i].first < lnum then target = list[i] break end
    end
    target = target or list[#list]
  end
  vim.cmd("normal! m'")
  vim.api.nvim_win_set_cursor(0, { target.first, 0 })
  M.preview()
end

-- Fills the quickfix list from a review file (defaults to this repo's
-- dev_review.md). Any markdown file using the same header format works, so an
-- agent's review can be loaded for comparison.
function M.quickfix(file)
  local root
  if file and file ~= "" then
    file = vim.fn.fnamemodify(file, ":p")
    root = git_root(file)
  else
    root = git_root(vim.api.nvim_buf_get_name(0))
    file = root and review_file(root)
  end
  if not root or vim.fn.filereadable(file) == 0 then
    vim.notify("No review file found", vim.log.levels.WARN)
    return
  end
  local items = {}
  for _, e in ipairs(parse(vim.fn.readfile(file)).entries) do
    table.insert(items, {
      filename = root .. "/" .. e.path,
      lnum = e.first,
      end_lnum = e.last,
      text = e.body[1] or "",
    })
  end
  vim.fn.setqflist({}, " ", { title = "Review: " .. vim.fn.fnamemodify(file, ":~:."), items = items })
  vim.cmd("copen")
end

function M.open_review_file()
  local root = current_location()
  if not root then return end
  local file = review_file(root)
  if vim.fn.filereadable(file) == 0 then
    save(root, load(root))
  end
  vim.cmd.edit(vim.fn.fnameescape(file))
end

-- Markdown link following ----------------------------------------------------

local function open_location(path, first, last)
  vim.cmd.edit(vim.fn.fnameescape(path))
  if not first then return end
  local count = vim.api.nvim_buf_line_count(0)
  first = math.min(first, count)
  last = math.min(last or first, count)
  vim.api.nvim_win_set_cursor(0, { first, 0 })
  vim.cmd("normal! zz")
  vim.hl.range(0, flash_ns, "Visual", { first - 1, 0 }, { last - 1, -1 }, { timeout = 800 })
end

-- Resolves a link target relative to the markdown file, then to the repo root.
local function resolve(target)
  local base = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  for _, dir in ipairs({ base, git_root(base) or base }) do
    local p = vim.fs.normalize(dir .. "/" .. target)
    if vim.uv.fs_stat(p) then return p end
  end
end

-- Follows, in order: a review entry header on the cursor line, a markdown link
-- under the cursor (`[x](path#L10-L20)` or a URL), or a bare `path:10-20`.
-- Returns false when there is nothing to follow.
function M.follow()
  local line = vim.api.nvim_get_current_line()
  local col = vim.fn.col(".")

  local path, first, last = line:match(HEADER)
  if path then
    local p = resolve(path)
    if p then
      open_location(p, tonumber(first), tonumber(last ~= "" and last or first))
      return true
    end
  end

  local init = 1
  while true do
    local s, e, target = line:find("%[[^%]]*%]%(([^)%s]+)[^)]*%)", init)
    if not s then break end
    if col >= s and col <= e then
      if target:match("^%a[%w+.-]*://") then
        vim.ui.open(target)
        return true
      end
      local file, anchor = target:match("^([^#]*)#?(.*)$")
      local a, b = anchor:match("^L(%d+)%-?L?(%d*)$")
      local p = file == "" and vim.api.nvim_buf_get_name(0) or resolve(file)
      if p then
        open_location(p, tonumber(a), tonumber(b ~= "" and b or a))
        return true
      end
      vim.notify("Link target not found: " .. file, vim.log.levels.WARN)
      return true
    end
    init = e + 1
  end

  local word = vim.fn.expand("<cWORD>"):gsub("^[`(%[<]+", ""):gsub("[`)%]>,.;:]+$", "")
  local wp, wa, wb = word:match("^(.-):(%d+)%-?(%d*)$")
  local p = resolve(wp or word)
  if p and vim.fn.isdirectory(p) == 0 then
    open_location(p, tonumber(wa), tonumber(wb ~= "" and wb or wa))
    return true
  end
  return false
end

-- Setup ------------------------------------------------------------------------

function M.setup()
  local map = vim.keymap.set
  map("n", "<leader>mc", M.comment_line, { desc = "Review: comment line / edit existing" })
  map("x", "<leader>mc", M.comment_range, { desc = "Review: comment selection" })
  map("n", "<leader>md", M.delete, { desc = "Review: delete comment" })
  map("n", "<leader>mk", M.preview, { desc = "Review: preview comment" })
  map("n", "<leader>ml", M.quickfix, { desc = "Review: comments to quickfix" })
  map("n", "<leader>mo", M.open_review_file, { desc = "Review: open review file" })
  map("n", "]r", function() M.jump(1) end, { desc = "Next review comment" })
  map("n", "[r", function() M.jump(-1) end, { desc = "Previous review comment" })

  vim.api.nvim_create_user_command("ReviewList", function(opts) M.quickfix(opts.args) end, {
    nargs = "?",
    complete = "file",
    desc = "Load review comments (default: pr_review/dev_review.md) into quickfix",
  })

  local group = vim.api.nvim_create_augroup("user_review", { clear = true })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufEnter" }, {
    group = group,
    callback = function(args) M.refresh(args.buf) end,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*/" .. REVIEW_REL,
    callback = refresh_all,
  })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "markdown",
    callback = function(args)
      if vim.api.nvim_buf_get_name(args.buf):match("^review://") then return end
      map("n", "<CR>", function()
        if not M.follow() then
          vim.api.nvim_feedkeys(vim.keycode("<CR>"), "n", false)
        end
      end, { buffer = args.buf, desc = "Follow link / review location" })
    end,
  })
end

return M
