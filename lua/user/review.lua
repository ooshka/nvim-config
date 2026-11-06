-- lua/user/review.lua
--
-- Inline PR review notes. Comments live in <repo>/pr_review/ as entries of the
-- form:
--
--   ## path/from/repo/root.lua:42-48
--   <!-- review-id: 1a2b3c sha: 990f9ab snippet: local x = compute() -->
--
--   Comment body (markdown).
--
--   A: agent reply
--   D: developer reply
--   ! note for the outgoing comment
--
-- The header is `gF`-compatible and is the only anchor; the metadata line is
-- optional, may carry extra fields, and always ends with `snippet` (the first
-- non-blank line of the range, used by the /pr-drift skill to re-anchor).
--
-- Files:
--   dev_review.md  your comments; new comments are added here.
--   outgoing.md    author-facing drafts; never shown.
--   context.md     the review agent's brief of the change; never shown.
--   anything else  agent reviews.
-- Any shown entry can be edited, including replying to agent comments. A body
-- line that is `!` or starts with `! ` flags the entry for sending. Entries
-- with `status: orphaned` have no valid location and get no signs.

local M = {}

local REVIEW_DIR = "pr_review"
local REVIEW_REL = REVIEW_DIR .. "/dev_review.md"
local ns = vim.api.nvim_create_namespace("user_review")
local flash_ns = vim.api.nvim_create_namespace("user_review_flash")

vim.api.nvim_set_hl(0, "ReviewSign", { link = "DiagnosticInfo", default = true })
vim.api.nvim_set_hl(0, "ReviewRange", { link = "NonText", default = true })
vim.api.nvim_set_hl(0, "ReviewAgentSign", { link = "DiagnosticHint", default = true })
vim.api.nvim_set_hl(0, "ReviewAgentRange", { link = "NonText", default = true })
vim.api.nvim_set_hl(0, "ReviewFlagSign", { link = "DiagnosticWarn", default = true })
vim.api.nvim_set_hl(0, "ReviewPendingSign", { link = "DiagnosticWarn", default = true })

local SIGNS = {
  dev = { icon = "\u{f075}", hl = "ReviewSign", range_hl = "ReviewRange", priority = 20 },
  agent = { icon = "\u{f06a9}", hl = "ReviewAgentSign", range_hl = "ReviewAgentRange", priority = 19 },
}
local FLAG_ICON, FLAG_HL = "\u{f024}", "ReviewFlagSign"
local PENDING_ICON, PENDING_HL = "\u{f252}", "ReviewPendingSign"

-- Entries waiting on the review agent, keyed by "<review file>#<review-id>".
M.pending = {}

-- Review file basename (without extension) -> kind; `false` hides the file.
-- Unlisted files are agent reviews.
local FILE_KINDS = { dev_review = "dev", outgoing = false, context = false }

-- Paths and git ------------------------------------------------------------

local function git_root(path)
  return vim.fs.root(path ~= "" and path or vim.fn.getcwd(), ".git")
end

local function review_file(root)
  return root .. "/" .. REVIEW_REL
end

-- Returns root and repo-relative path for a buffer, or nil for buffers that
-- are not files inside a git repository (or are review files themselves).
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
  if vim.startswith(rel, REVIEW_DIR .. "/") then
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
  for _, e in ipairs(entries) do
    if e.id then taken[e.id] = true end
  end
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
      current.meta = vim.trim(rest)
      current.severity = rest:match("severity: (%w+)")
      current.orphaned = rest:find("status: orphaned", 1, true) ~= nil
    elseif current then
      table.insert(current.body, line)
    else
      table.insert(doc.preamble, line)
    end
  end
  for _, e in ipairs(doc.entries) do
    e.body = trim_blank_edges(e.body)
    e.id = e.id or new_id(doc.entries)
    e.meta = e.meta or ""
    e.flagged = vim.iter(e.body):any(function(l) return l == "!" or vim.startswith(l, "! ") end)
  end
  return doc
end

local function load_file(file)
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

local function save(file, doc)
  local out = vim.deepcopy(trim_blank_edges(doc.preamble))
  if #out > 0 then table.insert(out, "") end
  for _, e in ipairs(doc.entries) do
    table.insert(out, string.format("## %s:%s", e.path, range_text(e)))
    table.insert(out, string.format("<!-- review-id: %s%s -->", e.id, e.meta ~= "" and (" " .. e.meta) or ""))
    table.insert(out, "")
    vim.list_extend(out, e.body)
    table.insert(out, "")
  end
  vim.fn.mkdir(vim.fs.dirname(file), "p")
  vim.fn.writefile(out, file)
  cache[file] = nil
  -- Keep an open buffer of the review file in step with the disk.
  local rbuf = vim.fn.bufnr(file)
  if rbuf ~= -1 and vim.api.nvim_buf_is_loaded(rbuf) and not vim.bo[rbuf].modified then
    vim.api.nvim_buf_call(rbuf, function() vim.cmd("checktime") end)
  end
end

-- Every shown review file under `root` as { file, source, kind }.
local function review_files(root)
  local list = {}
  for _, file in ipairs(vim.fn.glob(root .. "/" .. REVIEW_DIR .. "/*.md", true, true)) do
    local source = vim.fn.fnamemodify(file, ":t:r")
    local kind = FILE_KINDS[source]
    if kind == nil then kind = "agent" end
    if kind then
      table.insert(list, { file = vim.fs.normalize(file), source = source, kind = kind })
    end
  end
  return list
end

-- Entries from every shown review file, optionally only those for `rel`, each
-- tagged with `kind`, `source` (file name without extension) and `file`.
-- Orphaned entries are excluded unless `with_orphans` is set.
local function entries_for(root, rel, with_orphans)
  local list = {}
  for _, rf in ipairs(review_files(root)) do
    for _, e in ipairs(load_file(rf.file).entries) do
      if (not rel or e.path == rel) and (with_orphans or not e.orphaned) then
        table.insert(list, vim.tbl_extend("force", e, { kind = rf.kind, source = rf.source, file = rf.file }))
      end
    end
  end
  table.sort(list, function(a, b)
    if a.path ~= b.path then return a.path < b.path end
    return a.first < b.first
  end)
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
    local sign = SIGNS[e.kind]
    local icon, hl = sign.icon, sign.hl
    if M.pending[e.file .. "#" .. e.id] then
      icon, hl = PENDING_ICON, PENDING_HL
    elseif e.flagged then
      icon, hl = FLAG_ICON, FLAG_HL
    end
    for l = e.first, math.min(e.last, count) do
      local head = l == e.first
      vim.api.nvim_buf_set_extmark(buf, ns, l - 1, 0, {
        sign_text = head and icon or "│",
        sign_hl_group = head and hl or sign.range_hl,
        priority = sign.priority + (icon ~= sign.icon and 2 or 0),
      })
    end
  end
end

local function refresh_all()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    M.refresh(buf)
  end
end
M.refresh_all = refresh_all

-- Comment float ----------------------------------------------------------------

local function close_float(win)
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

local function find_entry(doc, id)
  for i, e in ipairs(doc.entries) do
    if e.id == id then return e, i end
  end
end

local function delete_entry(file, id)
  local doc = load_file(file)
  local _, idx = find_entry(doc, id)
  if idx then
    table.remove(doc.entries, idx)
    save(file, doc)
    refresh_all()
    vim.notify("Review comment deleted")
  end
end

-- Opens an editor float for `target` ({ root, file, path, first, last, id?,
-- snippet? }). Closing the float or `:w` writes the entry back into
-- `target.file`; an empty body removes the entry. A save is refused when the
-- entry changed on disk since the float last loaded or saved it, so replies
-- written by an agent in the meantime are never overwritten.
local function open_editor(target)
  local existing = target.id and find_entry(load_file(target.file), target.id)
  local source = vim.fn.fnamemodify(target.file, ":t:r")

  local name = string.format("review://%s/%s:%s#%s", source, target.path, range_text(target), target.id or "new")
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
    title = string.format(" %s · %s:%s ", source, target.path, range_text(target)),
    title_pos = "center",
    footer = " q/<Esc> save & close · <leader>ms ask agent · <leader>md delete ",
    footer_pos = "center",
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true

  local id = target.id
  local base_body = existing and vim.deepcopy(existing.body)
  local conflict = false

  -- Returns false when the save was refused.
  local function commit()
    local body = trim_blank_edges(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    local doc = load_file(target.file)
    local entry = id and find_entry(doc, id)
    if id and (not entry or not vim.deep_equal(entry.body, base_body)) then
      vim.notify(
        string.format("%s changed on disk since this comment was opened; not saved. "
          .. "Copy your text, close with :q!, and reopen the comment.", source .. ".md"),
        vim.log.levels.ERROR
      )
      conflict = true
      return false
    end
    if #body == 0 then
      if entry then delete_entry(target.file, id) end
      id, base_body = nil, nil
    else
      if entry then
        entry.body = body
      else
        id = new_id(doc.entries)
        table.insert(doc.entries, {
          id = id,
          path = target.path,
          first = target.first,
          last = target.last,
          meta = string.format("sha: %s snippet: %s", head_sha(target.root) or "unknown", target.snippet or ""),
          body = body,
        })
      end
      save(target.file, doc)
      base_body = vim.deepcopy(body)
      vim.notify("Review comment saved")
    end
    vim.bo[buf].modified = false
    refresh_all()
    return true
  end
  vim.api.nvim_create_autocmd("BufWriteCmd", { buffer = buf, callback = function() commit() end })

  local function save_and_close()
    if vim.bo[buf].modified and not commit() then return end
    close_float(win)
  end
  local function delete_and_close()
    if id then delete_entry(target.file, id) end
    vim.bo[buf].modified = false
    close_float(win)
  end
  vim.keymap.set("n", "q", save_and_close, { buffer = buf, desc = "Save and close review comment" })
  vim.keymap.set("n", "<Esc>", save_and_close, { buffer = buf, desc = "Save and close review comment" })
  vim.keymap.set("n", "<leader>md", delete_and_close, { buffer = buf, desc = "Delete review comment" })
  -- Saves, closes, and queues the comment for the review agent to answer.
  vim.keymap.set("n", "<leader>ms", function()
    if (vim.bo[buf].modified or not id) and not commit() then return end
    if not id then
      vim.notify("Write a question before asking the agent", vim.log.levels.WARN)
      return
    end
    close_float(win)
    require("user.review_agent").ask(target.root, target.file, id,
      string.format("%s:%s", target.path, range_text(target)))
  end, { buffer = buf, desc = "Save and ask the review agent" })
  -- Any :quit (including <leader>q) saves first, so closing never needs `!`.
  -- After a refused save, quitting no longer retries it: `:q` stops with E37
  -- and `:q!` discards the edit.
  vim.api.nvim_create_autocmd("QuitPre", {
    buffer = buf,
    callback = function()
      if vim.bo[buf].modified and not conflict then commit() end
    end,
  })

  if not existing then
    vim.cmd("startinsert")
  end
end

local preview = { win = nil, src_win = nil }

local function close_preview()
  if preview.win and vim.api.nvim_win_is_valid(preview.win) then
    vim.api.nvim_win_close(preview.win, true)
  end
  preview.win = nil
end

local function entry_label(e)
  return string.format("%s %s  %s", e.source, range_text(e), e.body[1] or "")
end

local function pick(entries, prompt, cb)
  if #entries == 1 then return cb(entries[1]) end
  vim.ui.select(entries, {
    prompt = prompt,
    format_item = function(e) return e.new and "+ New comment" or entry_label(e) end,
  }, function(choice)
    if choice then cb(choice) end
  end)
end

-- First non-blank line of the range, normalised as the metadata `snippet`.
local function snippet(first, last)
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, first - 1, last, false)) do
    local text = vim.trim(line)
    if text ~= "" then
      return (vim.fn.strcharpart(text, 0, 80):gsub("%-%-", "- -"))
    end
  end
  return ""
end

local function current_location()
  local root, rel = buf_location(0)
  if not root then
    vim.notify("Review comments need a file inside a git repository", vim.log.levels.WARN)
  end
  return root, rel
end

local function new_comment(root, rel, first, last)
  open_editor({
    root = root,
    file = review_file(root),
    path = rel,
    first = first,
    last = last,
    snippet = snippet(first, last),
  })
end

-- Normal mode: edit a comment (dev or agent) covering the cursor line, or
-- start a new one. With several candidates a picker also offers a new comment.
function M.comment_line()
  local root, rel = current_location()
  if not root then return end
  local lnum = vim.fn.line(".")
  local hits = entries_at(root, rel, lnum)
  if #hits == 0 then
    return new_comment(root, rel, lnum, lnum)
  end
  table.insert(hits, { new = true })
  pick(hits, "Edit review comment", function(e)
    if e.new then return new_comment(root, rel, lnum, lnum) end
    open_editor({ root = root, file = e.file, path = rel, first = e.first, last = e.last, id = e.id })
  end)
end

-- Visual mode: always start a new comment on the selected range.
function M.comment_range()
  local root, rel = current_location()
  local first, last = vim.fn.line("v"), vim.fn.line(".")
  if first > last then first, last = last, first end
  vim.cmd("normal! \27")
  if not root then return end
  new_comment(root, rel, first, last)
end

function M.delete()
  local root, rel = current_location()
  if not root then return end
  local hits = entries_at(root, rel, vim.fn.line("."))
  if #hits == 0 then
    vim.notify("No review comment on this line")
    return
  end
  pick(hits, "Delete review comment", function(e) delete_entry(e.file, e.id) end)
end

local function preview_lines(e)
  local lines = { string.format("**%s** · `%s:%s`", e.source, e.path, range_text(e)), "" }
  return vim.list_extend(lines, e.body)
end

local function show_preview(lines)
  -- The preview closes on a real cursor move away from where it opened. The
  -- built-in CursorMoved close event is not used because a jump that precedes
  -- the preview fires CursorMoved after the float is already open.
  close_preview()
  local src = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  preview.src_win = vim.api.nvim_get_current_win()
  local _, pwin = vim.lsp.util.open_floating_preview(lines, "markdown", {
    border = "rounded",
    max_width = 90,
    focus_id = "user_review",
    close_events = { "InsertEnter", "BufHidden" },
  })
  preview.win = pwin
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = src,
    callback = function()
      if not vim.api.nvim_win_is_valid(pwin) then return true end
      if vim.api.nvim_get_current_win() == pwin then return end
      local cur = vim.api.nvim_win_get_cursor(0)
      if cur[1] ~= pos[1] or cur[2] ~= pos[2] then
        vim.api.nvim_win_close(pwin, true)
        return true
      end
    end,
  })
end

-- Previews entry `id` of `file` when the cursor is still on its lines.
function M.preview_if_at(file, id)
  local root, rel = buf_location(0)
  if not root then return end
  local lnum = vim.fn.line(".")
  for _, e in ipairs(entries_at(root, rel, lnum)) do
    if e.file == file and e.id == id then
      close_preview()
      return M.preview()
    end
  end
end

-- With a preview already open (from ]r, ]q or a previous call), moves focus
-- into it so it can be scrolled; `q` inside closes it.
function M.preview()
  if preview.win and vim.api.nvim_win_is_valid(preview.win) then
    vim.api.nvim_set_current_win(preview.win)
    return
  end
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
    vim.list_extend(lines, preview_lines(e))
  end
  show_preview(lines)
end

-- direction: 1 for next, -1 for previous. Wraps around the file and previews
-- the comment landed on.
function M.jump(direction)
  -- From inside a focused preview, jump relative to the window it belongs to.
  if preview.win and vim.api.nvim_get_current_win() == preview.win
    and preview.src_win and vim.api.nvim_win_is_valid(preview.src_win) then
    vim.api.nvim_set_current_win(preview.src_win)
  end
  close_preview()
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

local function qf_set(root, title, entries)
  local items = {}
  for _, e in ipairs(entries) do
    local tag = e.source == "dev_review" and "dev" or e.source
    if e.severity then tag = tag .. "·" .. e.severity end
    if e.flagged then tag = tag .. " !" end
    if e.orphaned then tag = tag .. " orphaned" end
    table.insert(items, {
      filename = root .. "/" .. e.path,
      lnum = e.first,
      end_lnum = e.last,
      text = string.format("[%s] %s", tag, e.body[1] or ""),
      user_data = { review_preview = preview_lines(e) },
    })
  end
  vim.fn.setqflist({}, " ", { title = title, items = items })
  vim.cmd("copen")
  vim.cmd("wincmd p")
end

-- Fills the quickfix list with every shown review comment (dev and agent,
-- including orphaned ones) sorted by file and line, or with the entries of a
-- single review `file`. Each item carries its comment so stepping through the
-- list can preview it. Focus stays in the current window.
function M.quickfix(file)
  if file and file ~= "" then
    file = vim.fs.normalize(vim.fn.fnamemodify(file, ":p"))
    local root = git_root(file)
    if not root or vim.fn.filereadable(file) == 0 then
      vim.notify("No review file found: " .. file, vim.log.levels.WARN)
      return
    end
    local source = vim.fn.fnamemodify(file, ":t:r")
    local entries = vim.tbl_map(function(e)
      return vim.tbl_extend("force", e, { source = source })
    end, parse(vim.fn.readfile(file)).entries)
    return qf_set(root, "Review: " .. source, entries)
  end
  local root = git_root(vim.api.nvim_buf_get_name(0))
  local entries = root and entries_for(root, nil, true) or {}
  if #entries == 0 then
    vim.notify("No review comments found", vim.log.levels.WARN)
    return
  end
  qf_set(root, "Review: all comments", entries)
end

function M.quickfix_agent()
  local root = git_root(vim.api.nvim_buf_get_name(0))
  M.quickfix(root and (root .. "/" .. REVIEW_DIR .. "/agent_review.md") or nil)
end

-- Runs a quickfix motion (:cnext etc.) and previews the landed-on item when
-- it came from a review list.
function M.qf_step(cmd)
  close_preview()
  local ok, err = pcall(vim.cmd, vim.v.count1 .. cmd)
  if not ok then
    vim.notify((tostring(err):gsub("^.-:E", "E")), vim.log.levels.WARN)
    return
  end
  local qf = vim.fn.getqflist({ idx = 0, items = 0 })
  local item = qf.items[qf.idx]
  local data = item and item.user_data
  if type(data) == "table" and data.review_preview then
    show_preview(data.review_preview)
  end
end

function M.open_review_file()
  local root = current_location()
  if not root then return end
  local file = review_file(root)
  if vim.fn.filereadable(file) == 0 then
    save(file, load_file(file))
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
  require("user.review_agent").setup()
  local map = vim.keymap.set
  map("n", "<leader>mc", M.comment_line, { desc = "Review: comment line / edit existing" })
  map("x", "<leader>mc", M.comment_range, { desc = "Review: comment selection" })
  map("n", "<leader>md", M.delete, { desc = "Review: delete comment" })
  map("n", "<leader>mk", M.preview, { desc = "Review: preview comment" })
  map("n", "<leader>ml", function() M.quickfix() end, { desc = "Review: all comments to quickfix" })
  map("n", "<leader>ma", M.quickfix_agent, { desc = "Review: agent findings to quickfix" })
  map("n", "]q", function() M.qf_step("cnext") end, { desc = "Next quickfix item" })
  map("n", "[q", function() M.qf_step("cprevious") end, { desc = "Previous quickfix item" })
  map("n", "<leader>mo", M.open_review_file, { desc = "Review: open review file" })
  map("n", "]r", function() M.jump(1) end, { desc = "Next review comment" })
  map("n", "[r", function() M.jump(-1) end, { desc = "Previous review comment" })

  vim.api.nvim_create_user_command("ReviewList", function(opts) M.quickfix(opts.args) end, {
    nargs = "?",
    complete = "file",
    desc = "Load review comments (default: all review files) into quickfix",
  })

  local group = vim.api.nvim_create_augroup("user_review", { clear = true })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufEnter" }, {
    group = group,
    callback = function(args) M.refresh(args.buf) end,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*/" .. REVIEW_DIR .. "/*.md",
    callback = refresh_all,
  })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "markdown",
    callback = function(args)
      local name = vim.api.nvim_buf_get_name(args.buf)
      if name:match("^review://") then return end
      -- Lets the built-in gf/gF resolve repo-relative paths from any cwd.
      local root = name ~= "" and git_root(name)
      if root then
        vim.bo[args.buf].path = vim.go.path .. "," .. root
      end
      map("n", "<CR>", function()
        if not M.follow() then
          vim.api.nvim_feedkeys(vim.keycode("<CR>"), "n", false)
        end
      end, { buffer = args.buf, desc = "Follow link / review location" })
    end,
  })
end

return M
