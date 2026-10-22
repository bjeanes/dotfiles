-- Runs language servers inside a project's Docker Compose containers, for
-- projects whose dependencies only exist there.
--
-- A project opts in with a `.nvim/container-lsp.lua` at its root, trusted via
-- `vim.secure`. See container_lsp.example.lua for its shape.
--
-- Paths in every message are translated between host and container. Bind
-- mounts map to their host source, so edits land in the real files. Anything
-- else (volumes, the image's filesystem) maps into a per-container cache in
-- the temp dir, filled from the container as buffers are opened, so locations
-- inside dependencies (e.g. gems) can be read and navigated.
-- Roots without a matching project entry get the server's stock config.
local M = {}

local CONFIG = ".nvim/container-lsp.lua"
-- Missing files are refetched, so it's fine for the OS to clean this up
local CACHE = vim.fs.joinpath(vim.uv.os_tmpdir(), "nvim-container-lsp-" .. vim.uv.getuid())
vim.fn.mkdir(CACHE, "p", tonumber("700", 8))
-- Buffer names are resolved paths, so this must be too to match them
CACHE = vim.uv.fs_realpath(CACHE)

--- Active containerised clients, by server name then root.
---@type table<string, table<string, { mounts: table }>>
local sessions = {}

--- Untrusted project configs already warned about.
local warned = {}

local function run(cmd, cwd)
  local result = vim.system(cmd, { cwd = cwd, text = true }):wait()
  if result.code ~= 0 then
    error(("`%s` failed: %s"):format(table.concat(cmd, " "), result.stderr), 0)
  end
  return vim.trim(result.stdout)
end

local function load_project(root)
  local dirs = { root }
  for dir in vim.fs.parents(root) do
    table.insert(dirs, dir)
  end
  for _, dir in ipairs(dirs) do
    local path = vim.fs.joinpath(dir, CONFIG)
    if vim.uv.fs_stat(path) then
      -- Prompts until the file's current contents are trusted
      local source = vim.secure.read(path)
      if not source then
        if not warned[path] then
          warned[path] = true
          vim.notify(
            ("%s isn't trusted, so language servers run on the host. `:trust` it, then `:lsp restart`."):format(path),
            vim.log.levels.WARN
          )
        end
        return
      end
      return dir, assert(loadstring(source, "@" .. path))()
    end
  end
end

local function inspect_container(dir, compose, service)
  local function ps()
    local args = vim.list_extend(vim.deepcopy(compose), { "ps", "--quiet", "--status", "running", service })
    return vim.split(run(args, dir), "\n")[1]
  end
  local id = ps()
  if id == "" then
    vim.notify(("Starting %s for its language server"):format(service))
    run(vim.list_extend(vim.deepcopy(compose), { "up", "--detach", service }), dir)
    id = ps()
  end
  return vim.json.decode(run({ "docker", "inspect", id }))[1]
end

--- Host/container path pairs for a container. Paths not in a bind mount are
--- `cached`. The container's root is only used for URIs: a bare "/" is too
--- common in payloads (e.g. trigger characters) to rewrite.
local function container_mounts(info)
  local cache = vim.fs.joinpath(CACHE, info.Id)
  local mounts = { { host = cache, container = "/", cached = true, root = true } }
  for _, mount in ipairs(info.Mounts) do
    if mount.Type == "bind" and vim.uv.fs_stat(mount.Source) then
      table.insert(mounts, { host = mount.Source, container = mount.Destination })
    else
      -- Listed so that a volume nested in a bind mount (e.g. node_modules) wins
      table.insert(mounts, { host = cache .. mount.Destination, container = mount.Destination, cached = true })
    end
  end
  return mounts
end

--- Reads a cached container file into its buffer, fetching it on first use.
local function read_cached(args)
  local container, path = args.match:sub(#CACHE + 2):match("^([^/]+)(/.+)$")
  if not vim.uv.fs_stat(args.match) then
    local result = vim.system({ "docker", "exec", container, "cat", path }):wait()
    if result.code ~= 0 then
      vim.notify(("Couldn't read %s from container: %s"):format(path, result.stderr), vim.log.levels.ERROR)
      return
    end
    vim.fn.mkdir(vim.fs.dirname(args.match), "p")
    local file = assert(io.open(args.match, "wb"))
    file:write(result.stdout)
    file:close()
  end
  vim.api.nvim_buf_set_lines(args.buf, 0, -1, false, vim.fn.readfile(args.match))
  vim.bo[args.buf].modified = false
  vim.bo[args.buf].readonly = true
  vim.bo[args.buf].modifiable = false
  vim.api.nvim_buf_call(args.buf, function() vim.cmd.filetype("detect") end)
end

local function within(path, prefix)
  return prefix == "/" or path == prefix or vim.startswith(path, prefix .. "/")
end

local function join(prefix, rest)
  if rest == "" then
    return prefix
  end
  return prefix:gsub("/$", "") .. rest
end

--- Returns a function deep-copying an LSP payload with paths and URIs moved
--- from the `from` side of the mounts ("host" or "container") to the `to` side.
local function translator(mounts, from, to)
  local ordered = vim.deepcopy(mounts)
  -- Most specific first, so a volume nested in a bind mount wins
  table.sort(ordered, function(a, b) return #a[from] > #b[from] end)

  local function path(p, uri)
    for _, mount in ipairs(ordered) do
      if (uri or not mount.root) and within(p, mount[from]) then
        return join(mount[to], mount[from] == "/" and p or p:sub(#mount[from] + 1))
      end
    end
  end

  local function rewrite(s)
    -- URIs can be embedded anywhere, e.g. links in hover markdown
    s = s:gsub("file://(/[^%s\"'()<>#%[%]]*)", function(p)
      local mapped = path(vim.uri_decode(p), true)
      return mapped and vim.uri_from_fname(mapped)
    end)
    if s:match("^/%S*$") then
      s = path(s, false) or s
    end
    return s
  end

  local function walk(value)
    if type(value) == "string" then
      return rewrite(value)
    elseif type(value) ~= "table" then
      return value
    end
    local copy = {}
    -- Keys too: `WorkspaceEdit.changes` is keyed by URI
    for k, v in pairs(value) do
      copy[walk(k)] = walk(v)
    end
    -- Keeps the marker vim.empty_dict() uses to encode `{}` rather than `[]`
    return setmetatable(copy, getmetatable(value))
  end
  return walk
end

local function start_in_container(name, root, dispatchers)
  local dir, project = load_project(root)
  local server = project and project.servers and project.servers[name]
  local service = server and (server.services[vim.fs.relpath(dir, root)] or server.services["*"])
  if not service then
    return
  end

  local info = inspect_container(dir, project.compose or { "docker", "compose" }, service)
  local mounts = container_mounts(info)
  local to_container = translator(mounts, "host", "container")
  local to_host = translator(mounts, "container", "host")
  local workdir = to_container(root)
  assert(workdir ~= root, ("%s isn't mounted in %s"):format(root, service))

  sessions[name] = sessions[name] or {}
  sessions[name][root] = { mounts = mounts }

  local cmd = vim.list_extend({ "docker", "exec", "--interactive", "--workdir", workdir, info.Id }, server.cmd)
  local client = vim.lsp.rpc.start(cmd, {
    notification = function(method, params)
      return dispatchers.notification(method, to_host(params))
    end,
    server_request = function(method, params)
      local result, err = dispatchers.server_request(method, to_host(params))
      return to_container(result), err
    end,
    on_exit = function(...)
      sessions[name][root] = nil
      return dispatchers.on_exit(...)
    end,
    on_error = dispatchers.on_error,
  })

  return {
    request = function(method, params, callback, notify_reply_callback)
      return client.request(method, to_container(params), function(err, result, request_id)
        callback(err, to_host(result), request_id)
      end, notify_reply_callback)
    end,
    notify = function(method, params)
      return client.notify(method, to_container(params))
    end,
    is_closing = client.is_closing,
    terminate = client.terminate,
  }
end

--- Lets the named servers run in a project's containers.
---@param names string[]
function M.setup(names)
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = vim.api.nvim_create_augroup("container_lsp", {}),
    pattern = CACHE .. "/*",
    callback = read_cached,
  })

  for _, name in ipairs(names) do
    local default = vim.lsp.config[name]

    vim.lsp.config(name, {
      cmd = function(dispatchers, config)
        local root = config.cmd_cwd or config.root_dir
        local client = root and start_in_container(name, root, dispatchers)
        if client then
          return client
        elseif type(default.cmd) == "function" then
          return default.cmd(dispatchers, config)
        end
        return vim.lsp.rpc.start(default.cmd, dispatchers, root and { cwd = root })
      end,

      -- Files reached through a container's volumes or filesystem (e.g. after
      -- jumping into a gem) belong to the client that led there.
      root_dir = function(bufnr, on_dir)
        local path = vim.api.nvim_buf_get_name(bufnr)
        for root, session in pairs(sessions[name] or {}) do
          for _, mount in ipairs(session.mounts) do
            if mount.cached and within(path, mount.host) then
              return on_dir(root)
            end
          end
        end
        if type(default.root_dir) == "function" then
          return default.root_dir(bufnr, on_dir)
        end
        on_dir(default.root_dir or (default.root_markers and vim.fs.root(bufnr, default.root_markers)))
      end,
    })
  end
end

return M
