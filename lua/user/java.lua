-- Shared Java runtime checks for JVM-backed editor tooling.

local M = {}

local function java_version(java_bin)
  local result = vim.system({ java_bin, "-version" }, { text = true }):wait()
  local output = (result.stderr or "") .. (result.stdout or "")
  local version = output:match('version "([^"]+)"')
  local major = version and tonumber(version:match("^(%d+)"))

  if major == 1 then
    major = tonumber(version:match("^1%.(%d+)"))
  end

  return major, version
end

function M.cmd_env(tool_name, opts)
  opts = opts or {}

  local java_home = vim.env.JAVA_HOME
  if not java_home or java_home == "" then
    vim.notify(tool_name .. ": JAVA_HOME must point to JDK " .. opts.min_major .. "-" .. opts.max_major, vim.log.levels.WARN)
    return nil
  end

  local java_bin = java_home .. "/bin/java"
  if vim.fn.executable(java_bin) ~= 1 then
    vim.notify(tool_name .. ": JAVA_HOME/bin/java is not executable: " .. java_bin, vim.log.levels.ERROR)
    return nil
  end

  local major, version = java_version(java_bin)
  if not major then
    vim.notify(tool_name .. ": could not parse java version from " .. java_bin, vim.log.levels.ERROR)
    return nil
  end

  if opts.min_major and major < opts.min_major then
    vim.notify(tool_name .. ": JAVA_HOME is Java " .. version .. "; need >= " .. opts.min_major, vim.log.levels.ERROR)
    return nil
  end

  if opts.max_major and major > opts.max_major then
    vim.notify(tool_name .. ": JAVA_HOME is Java " .. version .. "; use Java " .. opts.max_major .. " or older", vim.log.levels.ERROR)
    return nil
  end

  return {
    JAVA_HOME = java_home,
    PATH = java_home .. "/bin:" .. (vim.env.PATH or ""),
  }
end

return M
