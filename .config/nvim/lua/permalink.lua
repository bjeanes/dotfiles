-- Permalinks to the current line(s) on the repository's forge.
--
-- Links point at the newest commit in HEAD's history that has been pushed (is
-- reachable from one of the remote's tracking branches), so they resolve even
-- when HEAD is local-only. Lines are mapped from the buffer (including unsaved
-- and uncommitted edits) back to that commit by diffing; lines that only exist
-- locally can't be linked.
--
-- The forge is picked from the remote's host: `hosts` in `setup()`, then a
-- repo's `git config permalink.forge <name>` (and optionally `permalink.url`
-- for the web root), then well-known hosts and hostname hints. Self-hosted
-- instances whose name gives nothing away need one of the first two.
local M = {}

---@class permalink.Forge
---@field url fun(ctx: permalink.Context): string

---@class permalink.Context
---@field base string Web root of the repository, without trailing slash
---@field sha string
---@field path string Repository-relative path, URL-encoded
---@field first integer
---@field last integer

--- Whether a forge would render the file rather than show its source, which
--- hides line anchors.
local function rendered(path)
  local ext = path:match("%.([^./]+)$")
  return ext ~= nil
    and vim.tbl_contains({ "md", "markdown", "mdx", "rst", "adoc", "asciidoc", "org", "textile", "rdoc" }, ext:lower())
end

---@type table<string, permalink.Forge>
M.forges = {
  github = {
    url = function(c)
      local lines = c.first == c.last and ("L%d"):format(c.first) or ("L%d-L%d"):format(c.first, c.last)
      return ("%s/blob/%s/%s%s#%s"):format(c.base, c.sha, c.path, rendered(c.path) and "?plain=1" or "", lines)
    end,
  },
  gitlab = {
    url = function(c)
      local lines = c.first == c.last and ("L%d"):format(c.first) or ("L%d-%d"):format(c.first, c.last)
      return ("%s/-/blob/%s/%s%s#%s"):format(c.base, c.sha, c.path, rendered(c.path) and "?plain=1" or "", lines)
    end,
  },
  -- Forgejo is a Gitea fork, with the same URLs
  gitea = {
    url = function(c)
      local lines = c.first == c.last and ("L%d"):format(c.first) or ("L%d-L%d"):format(c.first, c.last)
      return ("%s/src/commit/%s/%s%s#%s"):format(
        c.base,
        c.sha,
        c.path,
        rendered(c.path) and "?display=source" or "",
        lines
      )
    end,
  },
}
M.forges.forgejo = M.forges.gitea

local config = {
  --- By remote host. `url` is the web root, for when it differs from
  --- `https://<host>` (e.g. SSH on a separate hostname).
  ---@type table<string, { forge: string, url?: string }>
  hosts = {
    ["github.com"] = { forge = "github" },
    ["gitlab.com"] = { forge = "gitlab" },
    ["codeberg.org"] = { forge = "forgejo" },
  },
  --- Remote to link to when the current branch has no upstream, falling back
  --- to the only remote if there is just one.
  remote = "origin",
}

local function git(args, cwd)
  local result = vim.system(vim.list_extend({ "git" }, args), { cwd = cwd, text = true }):wait()
  if result.code ~= 0 then
    error(("`git %s` failed: %s"):format(table.concat(args, " "), vim.trim(result.stderr)), 0)
  end
  return result.stdout
end

local function try_git(args, cwd)
  local ok, out = pcall(git, args, cwd)
  return ok and vim.trim(out) or nil
end

local function pick_remote(root)
  local upstream = try_git({ "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}" }, root)
  local remotes = vim.split(vim.trim(git({ "remote" }, root)), "\n", { trimempty = true })
  if upstream then
    -- Remote names can contain slashes, so match against the known ones
    for _, remote in ipairs(remotes) do
      if vim.startswith(upstream, remote .. "/") then
        return remote
      end
    end
  end
  if vim.tbl_contains(remotes, config.remote) then
    return config.remote
  elseif #remotes == 1 then
    return remotes[1]
  end
  error(("No upstream or %q remote to link to"):format(config.remote), 0)
end

--- Host and repository path from a remote URL, in any of Git's forms.
local function parse_remote(url)
  local host, path = url:match("^%a[%w+.-]*://([^/]+)/(.+)$")
  if host then
    host = host:gsub("^.*@", ""):gsub(":%d+$", "")
  else
    -- scp-like: [user@]host:path
    host, path = url:match("^[^/:]-@?([^@/:]+):(.+)$")
  end
  if not host then
    error(("Can't parse remote URL %q"):format(url), 0)
  end
  return host:lower(), path:gsub("%.git/?$", ""):gsub("/$", "")
end

local function resolve_forge(root, host)
  local entry = config.hosts[host] or {}
  local name = entry.forge or try_git({ "config", "permalink.forge" }, root)
  local url = entry.url or try_git({ "config", "permalink.url" }, root)
  if not name then
    for _, hint in ipairs({ "github", "gitlab", "forgejo", "gitea" }) do
      if host:find(hint, 1, true) then
        name = hint
        break
      end
    end
  end
  if not name then
    error(("Unknown forge for %s; set `git config permalink.forge <name>`"):format(host), 0)
  end
  local forge = M.forges[name]
  if not forge then
    error(("Unsupported forge %q"):format(name), 0)
  end
  return forge, url and url:gsub("/$", "")
end

--- Newest commit in HEAD's history that the remote has.
local function pushed_base(root, remote)
  local unpushed = git({ "rev-list", "--boundary", "HEAD", "--not", "--remotes=" .. remote }, root)
  if unpushed == "" then
    return vim.trim(git({ "rev-parse", "HEAD" }, root))
  end
  local boundary = {}
  for sha in unpushed:gmatch("%-(%x+)") do
    table.insert(boundary, sha)
  end
  if #boundary == 0 then
    error(("No commit in HEAD's history is on %s (try fetching)"):format(remote), 0)
  end
  -- Past a merge there can be several; prefer the newest
  return vim.trim(git(vim.list_extend({ "rev-list", "-1", "--date-order" }, boundary), root))
end

--- Path of `path` (as in the working tree) at `rev`, following renames.
local function path_at(root, rev, path)
  if try_git({ "cat-file", "-e", rev .. ":" .. path }, root) then
    return path
  end
  local status = git({ "diff", "-M", "--name-status", "-z", rev }, root)
  local fields = vim.split(status, "\0", { trimempty = true })
  local i = 1
  while i <= #fields do
    local kind = fields[i]
    if kind:match("^[RC]") then
      if fields[i + 2] == path then
        return fields[i + 1]
      end
      i = i + 3
    else
      i = i + 2
    end
  end
  error(("%s isn't on the forge"):format(path), 0)
end

--- Maps buffer lines `first`..`last` to lines in `old`. Returns the mapped
--- range, or nil when none of the lines exist in `old`, and whether any of
--- them were changed.
local function map_lines(old, new, first, last)
  local diff = vim.text and vim.text.diff or vim.diff
  local hunks = diff(old, new, { result_type = "indices", algorithm = "histogram" }) --[[@as integer[][] ]]

  -- First line after a hunk's side. An empty side's start is the line before
  -- it, rather than its first line.
  local function after(start, count)
    return count > 0 and start + count or start + 1
  end

  -- Position in `old` of a line, or nil for lines changed in `new`
  local function map(line)
    local offset = 0
    for _, h in ipairs(hunks) do
      local old_start, old_count, new_start, new_count = unpack(h)
      local new_after = after(new_start, new_count)
      if line >= new_after then
        offset = after(old_start, old_count) - new_after
      elseif new_count > 0 and line >= new_start then
        return nil
      end
    end
    return line + offset
  end

  local mapped, changed = {}, false
  for line = first, last do
    local old_line = map(line)
    if old_line then
      table.insert(mapped, old_line)
    else
      changed = true
    end
  end
  if #mapped == 0 then
    return nil, changed
  end
  return { mapped[1], mapped[#mapped] }, changed
end

local function encode_path(path)
  return (path:gsub("[^%w%-%._~/]", function(c)
    return ("%%%02X"):format(c:byte())
  end))
end

--- Permalink for lines `first`..`last` of `buf`.
---@return string
function M.url(buf, first, last)
  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" or vim.bo[buf].buftype ~= "" then
    error("Buffer isn't a file", 0)
  end
  file = vim.uv.fs_realpath(file) or file
  local root = try_git({ "rev-parse", "--show-toplevel" }, vim.fs.dirname(file))
  if not root then
    error("Not in a Git repository", 0)
  end
  root = vim.uv.fs_realpath(root) or root
  local path = file:sub(#root + 2)

  local remote = pick_remote(root)
  local host, repo = parse_remote(vim.trim(git({ "remote", "get-url", remote }, root)))
  local forge, base = resolve_forge(root, host)

  local sha = pushed_base(root, remote)
  local old_path = path_at(root, sha, path)
  local old = git({ "cat-file", "blob", sha .. ":" .. old_path }, root)
  if vim.bo[buf].fileformat == "dos" then
    old = old:gsub("\r\n", "\n")
  end
  local new = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n"

  local range, changed = map_lines(old, new, first, last)
  if not range then
    error("Selected lines only exist locally", 0)
  elseif changed then
    vim.notify("Selection includes local changes; linking to the pushed version", vim.log.levels.WARN)
  end

  return forge.url({
    base = base or ("https://%s/%s"):format(host, repo),
    sha = sha,
    path = encode_path(old_path),
    first = range[1],
    last = range[2],
  })
end

local actions = {
  copy = function(url)
    vim.fn.setreg("+", url)
    vim.notify("Copied " .. url)
  end,
  open = function(url)
    vim.ui.open(url)
  end,
}

---@param opts? { hosts?: table<string, { forge: string, url?: string }>, remote?: string }
function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})

  for name, action in pairs(actions) do
    local command = "Permalink" .. name:sub(1, 1):upper() .. name:sub(2)
    vim.api.nvim_create_user_command(command, function(args)
      local ok, result = pcall(M.url, 0, args.line1, args.line2)
      if ok then
        action(result)
      else
        vim.notify(result, vim.log.levels.ERROR)
      end
    end, { range = true, desc = ("%s permalink to line(s) on the forge"):format(name) })
  end
end

return M
