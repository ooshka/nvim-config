-- lua/user/review_agent.lua
--
-- Background review agent. Requests from Neovim (review the branch, answer one
-- comment, reply to everything waiting, re-anchor lines) go into a queue that a
-- single headless Claude session per repository works through one at a time,
-- so it is the only agent writing to pr_review/ and never races itself.
--
-- pr_review/.session holds the session id and, on its second line, the total
-- cost in USD of the requests run in it (as reported by `claude -p`). The first request without one
-- starts a session that builds pr_review/context.md before doing the request;
-- later requests resume that session. When HEAD has commits beyond the base
-- branch the brief describes that change (PR mode). Otherwise (e.g. on main)
-- there is nothing to review, the comments are questions about the project,
-- and the brief is built from them and the code they point at (explore mode). The review
-- files are the source of truth, so a lost session only costs a re-read:
-- delete .session (or :ReviewNewSession) to start over. `vim.g.review_agent_model`
-- overrides the model.

local review = require("user.review")

local M = {}

local DIR = "pr_review"

-- The agent may read anything, run read-only git commands, and write only
-- inside pr_review/. Headless runs cannot ask for permission, so anything else
-- is denied.
local ALLOWED_TOOLS = {
  "Read", "Grep", "Glob", "Skill",
  "Write(" .. DIR .. "/**)", "Edit(" .. DIR .. "/**)",
  "Bash(git diff:*)", "Bash(git log:*)", "Bash(git show:*)", "Bash(git status:*)",
  "Bash(git rev-parse:*)", "Bash(git merge-base:*)", "Bash(git cat-file:*)",
  "Bash(git ls-files:*)", "Bash(git blame:*)",
}

local queue = {}
local running = nil

local function session_file(root)
  return root .. "/" .. DIR .. "/.session"
end

-- Returns the session id (or nil) and its accumulated cost.
local function read_session(root)
  local ok, lines = pcall(vim.fn.readfile, session_file(root))
  local id = ok and lines[1] and vim.trim(lines[1]) or ""
  if id == "" then return nil, 0 end
  return id, tonumber(lines[2]) or 0
end

local function write_session(root, id, cost)
  vim.fn.mkdir(root .. "/" .. DIR, "p")
  vim.fn.writefile({ id, string.format("%.4f", cost) }, session_file(root))
end

local function dollars(cost)
  return string.format("$%.2f", cost)
end

local function git(root, args)
  local out = vim.system(vim.list_extend({ "git", "-C", root }, args), { text = true }):wait()
  return out.code == 0 and vim.trim(out.stdout) or nil
end

-- "pr" when HEAD has commits that its base branch does not, "explore"
-- otherwise (on the base branch, in sync with it, or no base found).
local function mode(root)
  local base = git(root, { "rev-parse", "--abbrev-ref", "origin/HEAD" }) or "main"
  local ahead = git(root, { "rev-list", "--count", base .. "..HEAD" })
  return (tonumber(ahead) or 0) > 0 and "pr" or "explore"
end

local COMMON_PREAMBLE = {
  "You are the review agent for this repository, running headless through the",
  "user's Neovim review queue. Nobody can answer questions mid-run, so make",
  "reasonable choices and mention them in your final message. Create or edit",
  "files only under pr_review/.",
  "",
}

local function explore_prompt()
  return table.concat(vim.list_extend(vim.deepcopy(COMMON_PREAMBLE), {
    "There is no change under review: HEAD has no commits beyond its base branch.",
    "The comments in pr_review/ are the user's questions while learning this",
    "project, not review findings. Answer them as explanations: how the code",
    "works, why it is shaped that way, and where to look next. Treat any",
    "pr-discuss instructions about reviewing a PR in that light.",
    "",
    "First, make sure pr_review/context.md is a current brief. If it exists, read",
    "it. Otherwise create it: read pr_review/dev_review.md (and any other review",
    "files), then the code each comment points at and enough around it to explain",
    "it, then write a short orientation: what the project does, the main modules",
    "involved in the comments and how they fit together, and recurring themes in",
    "the questions. Keep it under 60 lines, hard-wrapped at 80, and start it with",
    "`Mode: explore`.",
    "",
    "Then do the following request.",
    "",
  }), "\n")
end

local function pr_prompt()
  return table.concat(vim.list_extend(vim.deepcopy(COMMON_PREAMBLE), {
    "First, make sure pr_review/context.md is a current brief of the change. If it",
    "exists, read it and update it if HEAD has moved past the head it records.",
    "Otherwise create it: find the base (`git rev-parse --abbrev-ref origin/HEAD`,",
    "falling back to main), read `git diff <base>...HEAD -- . ':(exclude)pr_review'`",
    "and enough surrounding code to understand the change, then write: base and",
    "head sha, the purpose of the change, each touched file with one line on what",
    "changed, and the areas of risk. Keep it under 60 lines, hard-wrapped at 80.",
    "Read pr_review/dev_review.md and pr_review/agent_review.md if they exist.",
    "",
    "Then do the following request.",
    "",
  }), "\n")
end

local function request_prompt(req)
  if req.kind == "review" then
    return "Use the pr-review skill. If pr_review/agent_review.md exists, replace it;"
      .. " the user has confirmed."
  elseif req.kind == "discuss" then
    return "Use the pr-discuss skill."
  elseif req.kind == "drift" then
    return "Use the pr-drift skill."
  elseif req.kind == "ask" then
    return string.format(table.concat({
      "The user is waiting on a reply to one comment: the entry with",
      "`review-id: %s` in pr_review/%s.md (anchored at %s). Re-read the file, since",
      "it may have changed. Reply to that entry only, following the pr-discuss",
      "skill's rules for replying and for what you may change.",
    }, " "), req.id, req.source, req.where)
  end
end

local function describe(req)
  if req.kind == "ask" then
    return "answer " .. req.where
  end
  return ({ review = "review the branch", discuss = "reply to waiting comments", drift = "re-anchor comments" })[req.kind]
end

local function pending_key(req)
  return req.file .. "#" .. req.id
end

local function finish(req, ok, message, cost)
  if req.kind == "ask" then
    review.pending[pending_key(req)] = nil
  end
  vim.cmd("silent! checktime")
  if ok and req.before then
    review.mark_changed(req.root, req.before)
  end
  review.refresh_all()
  local level = ok and vim.log.levels.INFO or vim.log.levels.ERROR
  vim.notify(string.format("Review agent (%s%s): %s", describe(req),
    cost and (", " .. dollars(cost)) or "", message), level)
  if ok and req.kind == "ask" then
    review.preview_if_at(req.file, req.id)
  end
end

local pump

local function on_exit(req, session, session_cost, out)
  running = nil
  local ok_json, data = pcall(vim.json.decode, out.stdout or "")
  if out.code ~= 0 or not ok_json or type(data) ~= "table" then
    local err = vim.trim((out.stderr or "") .. "\n" .. (out.stdout or ""))
    if session and err:find("No conversation found", 1, true) and not req.retried then
      os.remove(session_file(req.root))
      req.retried = true
      table.insert(queue, 1, req)
      vim.notify("Review agent: session not found, starting a new one", vim.log.levels.WARN)
    else
      finish(req, false, err ~= "" and err:sub(1, 400) or ("exit code " .. out.code))
    end
    return pump()
  end

  local cost = tonumber(data.total_cost_usd) or 0
  local id = data.session_id or session
  if id then
    write_session(req.root, id, (id == session and session_cost or 0) + cost)
  end
  local result = vim.trim(tostring(data.result or ""))
  finish(req, not data.is_error, result ~= "" and result or "done", cost)
  pump()
end

pump = function()
  if running or #queue == 0 then return end
  local req = table.remove(queue, 1)
  local session, session_cost = read_session(req.root)
  req.before = review.snapshot(req.root)
  local bootstrap = ""
  if not session then
    bootstrap = mode(req.root) == "pr" and pr_prompt() or explore_prompt()
  end
  local prompt = bootstrap .. request_prompt(req)

  local cmd = { "claude", "-p", "--output-format", "json" }
  if vim.g.review_agent_model then
    vim.list_extend(cmd, { "--model", vim.g.review_agent_model })
  end
  table.insert(cmd, "--allowedTools")
  vim.list_extend(cmd, ALLOWED_TOOLS)
  if session then
    vim.list_extend(cmd, { "--resume", session })
  end
  vim.list_extend(cmd, { "--", prompt })

  local ok, handle = pcall(vim.system, cmd, { cwd = req.root, text = true }, function(out)
    vim.schedule(function() on_exit(req, session, session_cost, out) end)
  end)
  if not ok then
    finish(req, false, "could not start claude: " .. tostring(handle))
    return pump()
  end
  running = { req = req, handle = handle, started = vim.uv.now() }
end

local function enqueue(req)
  for _, q in ipairs(queue) do
    if q.kind == req.kind and q.root == req.root and q.id == req.id then
      vim.notify("Review agent: already queued (" .. describe(req) .. ")")
      return
    end
  end
  if req.kind == "ask" then
    review.pending[pending_key(req)] = true
    review.refresh_all()
  end
  table.insert(queue, req)
  local ahead = #queue - 1 + (running and 1 or 0)
  vim.notify(string.format("Review agent: queued %s%s", describe(req),
    ahead > 0 and string.format(" (%d ahead)", ahead) or ""))
  pump()
end

local function current_root()
  local root = vim.fs.root(vim.api.nvim_buf_get_name(0) ~= "" and vim.api.nvim_buf_get_name(0) or vim.fn.getcwd(), ".git")
  if not root then
    vim.notify("Review agent: not inside a git repository", vim.log.levels.WARN)
  end
  return root and vim.fs.normalize(root)
end

-- Public requests ------------------------------------------------------------

-- `file` is the absolute review file, `id` the entry's review-id, `where` its
-- `path:range` (for messages).
function M.ask(root, file, id, where)
  enqueue({
    kind = "ask",
    root = root,
    file = file,
    id = id,
    where = where,
    source = vim.fn.fnamemodify(file, ":t:r"),
  })
end

function M.review()
  local root = current_root()
  if not root then return end
  if mode(root) == "explore" then
    vim.notify("Review agent: HEAD has no commits beyond its base branch, so there is"
      .. " nothing to review. Ask about comments with <leader>ms instead.",
      vim.log.levels.WARN)
    return
  end
  if vim.uv.fs_stat(root .. "/" .. DIR .. "/agent_review.md") then
    local choice = vim.fn.confirm("pr_review/agent_review.md exists. Replace it?", "&Replace\n&Cancel", 2)
    if choice ~= 1 then return end
  end
  enqueue({ kind = "review", root = root })
end

function M.discuss()
  local root = current_root()
  if root then enqueue({ kind = "discuss", root = root }) end
end

function M.drift()
  local root = current_root()
  if root then enqueue({ kind = "drift", root = root }) end
end

function M.status()
  local lines = {}
  if running then
    table.insert(lines, string.format("running: %s (%ds)", describe(running.req),
      math.floor((vim.uv.now() - running.started) / 1000)))
  end
  for i, q in ipairs(queue) do
    table.insert(lines, string.format("%d. %s", i, describe(q)))
  end
  local root = current_root()
  local session, cost = nil, 0
  if root then session, cost = read_session(root) end
  if #lines == 0 then table.insert(lines, "idle") end
  table.insert(lines, "session: " .. (session or "none (next request starts one)"))
  local header = session and ("Review agent · session " .. dollars(cost)) or "Review agent"
  vim.notify(header .. "\n" .. table.concat(lines, "\n"))
end

function M.cancel()
  for _, q in ipairs(queue) do
    if q.kind == "ask" then review.pending[pending_key(q)] = nil end
  end
  queue = {}
  if running then
    running.handle:kill("sigterm")
  end
  review.refresh_all()
end

function M.new_session()
  local root = current_root()
  if not root then return end
  os.remove(session_file(root))
  vim.notify("Review agent: the next request starts a new session")
end

function M.setup()
  local map = vim.keymap.set
  map("n", "<leader>mr", M.review, { desc = "Review agent: review the branch" })
  map("n", "<leader>ms", M.discuss, { desc = "Review agent: reply to waiting comments" })
  map("n", "<leader>mf", M.drift, { desc = "Review agent: re-anchor comments" })
  map("n", "<leader>mq", M.status, { desc = "Review agent: queue status" })
  vim.api.nvim_create_user_command("ReviewCancel", M.cancel, { desc = "Stop the review agent and clear its queue" })
  vim.api.nvim_create_user_command("ReviewNewSession", M.new_session, { desc = "Start a new review agent session on the next request" })
end

return M
