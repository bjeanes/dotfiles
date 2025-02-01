
-- Nixvim's internal module table
-- Can be used to share code throughout init.lua
local _M = {}

-- Set up globals {{{
do
    local nixvim_globals = { mapleader = " ", maplocalleader = " " }

    for k, v in pairs(nixvim_globals) do
        vim.g[k] = v
    end
end
-- }}}

-- Set up options {{{
do
    local nixvim_options = { pumblend = 0, termguicolors = true, winblend = 0 }

    for k, v in pairs(nixvim_options) do
        vim.opt[k] = v
    end
end
-- }}}

require("catppuccin").setup({
    default_integrations = true,
    flavour = "macchiato",
    integrations = { cmp = true, mini = { enabled = true }, treesitter = true },
    term_colors = true,
    transparent_background = true,
})

vim.diagnostic.config({
    float = { border = "rounded" },
    jump = { severity = vim.diagnostic.severity.WARN },
    severity_sort = true,
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = "",
            [vim.diagnostic.severity.HINT] = "󰌵",
            [vim.diagnostic.severity.INFO] = "",
            [vim.diagnostic.severity.WARN] = "",
        },
        texthl = {
            [vim.diagnostic.severity.ERROR] = "DiagnosticError",
            [vim.diagnostic.severity.HINT] = "DiagnosticHint",
            [vim.diagnostic.severity.INFO] = "DiagnosticInfo",
            [vim.diagnostic.severity.WARN] = "DiagnosticWarn",
        },
    },
    update_in_insert = true,
})

vim.cmd([[colorscheme catppuccin
]])

require("mini.ai").setup({})

require("mini.animate").setup({
    close = { enable = false },
    cursor = { enable = false },
    open = { enable = false },
    resize = {
        -- Animate only for 100ms
        timing = require("mini.animate").gen_timing.linear({
            duration = 100,
            unit = "total",
        }),
    },
    scroll = {
        -- Animate only for 100ms
        timing = require("mini.animate").gen_timing.linear({
            duration = 100,
            unit = "total",
        }),
    },
})

require("mini.basics").setup({ mappings = { option_toggle_prefix = "<Leader>t" }, options = { extra_ui = true } })

require("mini.bracketed").setup({})

require("mini.bufremove").setup({})

require("mini.comment").setup({})

require("mini.cursorword").setup({})

require("mini.extra").setup({})

require("mini.hipatterns").setup({
    fixme = { group = "MiniHipatternsFixme", pattern = "%f[%w]()FIXME()%f[%W]" },
    hack = { group = "MiniHipatternsHack", pattern = "%f[%w]()HACK()%f[%W]" },
    -- Highlight hex color strings (`#rrggbb`) using that color
    hex_color = require("mini.hipatterns").gen_highlighter.hex_color(),
    note = { group = "MiniHipatternsNote", pattern = "%f[%w]()NOTE()%f[%W]" },
    todo = { group = "MiniHipatternsTodo", pattern = "%f[%w]()TODO()%f[%W]" },
})

require("mini.icons").setup({})

require("mini.indentscope").setup({
    draw = { animation = require("mini.indentscope").gen_animation.none() },
    options = { try_as_border = true },
})

require("mini.jump").setup({})

require("mini.move").setup({})

require("mini.pairs").setup({})

require("mini.pick").setup({})

require("mini.surround").setup({ mappings = { add = "S", delete = "ds", replace = "cs" } })
MiniIcons.mock_nvim_web_devicons()

vim.ui.select = require("mini.pick").ui_select

-- LSP {{{
do
    local __lspServers = {}
    -- Adding lspOnAttach function to nixvim module lua table so other plugins can hook into it.
    _M.lspOnAttach = function(client, bufnr) end
    local __lspCapabilities = function()
        capabilities = vim.lsp.protocol.make_client_capabilities()

        return capabilities
    end

    local __setup = {
        on_attach = _M.lspOnAttach,
        capabilities = __lspCapabilities(),
    }

    for i, server in ipairs(__lspServers) do
        if type(server) == "string" then
            require("lspconfig")[server].setup(__setup)
        else
            local options = server.extraOptions

            if options == nil then
                options = __setup
            else
                options = vim.tbl_extend("keep", options, __setup)
            end

            require("lspconfig")[server.name].setup(options)
        end
    end
end
-- }}}

require("which-key").setup({})

require("treesitter-context").setup({ max_lines = 4, min_window_height = 40, separator = "-" })

vim.opt.runtimepath:prepend(vim.fs.joinpath(vim.fn.stdpath("data"), "site"))
require("nvim-treesitter.configs").setup({
    highlight = {
        additional_vim_regex_highlighting = true,
        disable = function(lang, bufnr)
            return vim.api.nvim_buf_line_count(bufnr) > 10000
        end,
        enable = true,
    },
    incremental_selection = { enable = true },
    indent = { enable = true },
    parser_install_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site"),
    refactor = {
        highlight_current_scope = { enable = false },
        highlight_definitions = { clear_on_cursor_move = true, enable = true },
        navigation = {
            enable = true,
            keymaps = {
                goto_definition = "gnd",
                goto_next_usage = "<a-*>",
                goto_previous_usage = "<a-#>",
                list_definitions = "gnD",
                list_definitions_toc = "gO",
            },
        },
        smart_rename = { enable = true, keymaps = { smart_rename = "grr" } },
    },
})

require("snacks").setup({
    bigfile = { enabled = true },
    dashboard = {
        enabled = true,
        preset = {
            header = " _______                 ______                    __                     \n|       \\               /      \\                  |  \\                    \n| ▓▓▓▓▓▓▓\\ ______      |  ▓▓▓▓▓▓\\ ______  _______  \\▓▓__    __  _______   \n| ▓▓__/ ▓▓/      \\     | ▓▓ __\\▓▓/      \\|       \\|  \\  \\  |  \\/       \\  \n| ▓▓    ▓▓  ▓▓▓▓▓▓\\    | ▓▓|    \\  ▓▓▓▓▓▓\\ ▓▓▓▓▓▓▓\\ ▓▓ ▓▓  | ▓▓  ▓▓▓▓▓▓▓  \n| ▓▓▓▓▓▓▓\\ ▓▓    ▓▓    | ▓▓ \\▓▓▓▓ ▓▓    ▓▓ ▓▓  | ▓▓ ▓▓ ▓▓  | ▓▓\\▓▓    \\   \n| ▓▓__/ ▓▓ ▓▓▓▓▓▓▓▓    | ▓▓__| ▓▓ ▓▓▓▓▓▓▓▓ ▓▓  | ▓▓ ▓▓ ▓▓__/ ▓▓_\\▓▓▓▓▓▓\\  \n| ▓▓    ▓▓\\▓▓     \\     \\▓▓    ▓▓\\▓▓     \\ ▓▓  | ▓▓ ▓▓\\▓▓    ▓▓       ▓▓  \n \\▓▓▓▓▓▓▓  \\▓▓▓▓▓▓▓      \\▓▓▓▓▓▓  \\▓▓▓▓▓▓▓\\▓▓   \\▓▓\\▓▓ \\▓▓▓▓▓▓ \\▓▓▓▓▓▓▓   \n",
            keys = {
                { action = ":Pick files", desc = "Find File", icon = " ", key = "f" },
                { action = ":ene | startinsert", desc = "New File", icon = " ", key = "n" },
                { action = ":Pick grep_live", desc = "Find Text", icon = " ", key = "g" },
                { action = ":Pick oldfiles", desc = "Recent Files", icon = " ", key = "r" },
                {
                    action = ":lua Snacks.dashboard.pick('files', {cwd = \"~/.config/nvim\"})",
                    desc = "Config",
                    icon = " ",
                    key = "c",
                },
                { desc = "Restore Session", icon = " ", key = "s", section = "session" },
                { action = ":qa", desc = "Quit", icon = " ", key = "q" },
            },
        },
        sections = {
            { section = "header" },
            { indent = 2, padding = 2, section = "keys", title = "Keymaps" },
            { icon = " ", indent = 2, padding = 2, section = "recent_files", title = "Recent Files" },
            { icon = " ", indent = 2, padding = 2, section = "projects", title = "Projects" },
        },
    },
    git = { enabled = true },
    gitbrowse = { enabled = true },
    lazygit = { enabled = true },
    notifier = { enabled = true },
    quickfile = { enabled = true },
    scratch = { enabled = true },
    statuscolumn = { enabled = true },
    terminal = { enabled = true },
})

require("nvim-navic").setup({ lsp = { auto_attach = true } })

require("gitblame").setup({ virtual_text_column = 60 })

local slow_format_filetypes = {}

vim.api.nvim_create_user_command("FormatDisable", function(args)
    if args.bang then
        -- FormatDisable! will disable formatting just for this buffer
        vim.b.disable_autoformat = true
    else
        vim.g.disable_autoformat = true
    end
end, {
    desc = "Disable autoformat-on-save",
    bang = true,
})

vim.api.nvim_create_user_command("FormatEnable", function()
    vim.b.disable_autoformat = false
    vim.g.disable_autoformat = false
end, {
    desc = "Re-enable autoformat-on-save",
})

vim.api.nvim_create_user_command("FormatToggle", function(args)
    if args.bang then
        -- Toggle formatting for current buffer
        vim.b.disable_autoformat = not vim.b.disable_autoformat
    else
        -- Toggle formatting globally
        vim.g.disable_autoformat = not vim.g.disable_autoformat
    end
end, {
    desc = "Toggle autoformat-on-save",
    bang = true,
})

require("conform").setup({
    default_format_opts = { lsp_format = "last" },
    format_after_save = function(bufnr)
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
            return
        end

        if not slow_format_filetypes[vim.bo[bufnr].filetype] then
            return
        end

        return { lsp_format = "last" }
    end,
    format_on_save = function(bufnr)
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
            return
        end

        if slow_format_filetypes[vim.bo[bufnr].filetype] then
            return
        end

        local function on_format(err)
            if err and err:match("timeout$") then
                slow_format_filetypes[vim.bo[bufnr].filetype] = true
            end
        end

        return { timeout_ms = 300, lsp_format = "last" }, on_format
    end,
    formatters = {
        biome = { command = "biome" },
        jq = { command = "jq" },
        mdformat = { command = "mdformat" },
        nixfmt = { command = "nixfmt" },
        prettierd = { command = "prettierd" },
        rustfmt = { command = "rustfmt" },
        shellcheck = { command = "shellcheck" },
        shellharden = { command = "shellharden" },
        shfmt = { command = "shfmt" },
        sqlfluff = { command = "sqlfluff" },
        stylelint = { command = "stylelint" },
        stylua = { command = "stylua" },
        taplo = { command = "taplo" },
        terraform_fmt = { command = "terraform" },
        xmlformat = { command = "xmlformat" },
        yamlfmt = { command = "yamlfmt" },
    },
    formatters_by_ft = {
        _ = { "trim_whitespace", "trim_newlines" },
        bash = { "shellcheck", "shellharden", "shfmt" },
        css = { "stylelint" },
        javascript = { "biome", "prettierd", stop_after_first = true, timeout_ms = 2000 },
        json = { "jq" },
        lua = { "stylua" },
        markdown = { "injected", "mdformat" },
        nix = { "nixfmt" },
        rust = { "rustfmt" },
        sh = { "shellcheck", "shellharden", "shfmt" },
        sql = { "sqlfluff" },
        terraform = { "terraform_fmt" },
        toml = { "taplo" },
        typescript = { "biome", "prettierd", stop_after_first = true, timeout_ms = 2000 },
        xml = { "xmlformat", "xmllint" },
        yaml = { "yamlfmt" },
    },
})

require("neo-tree").setup({
    close_if_last_window = true,
    document_symbols = { custom_kinds = {} },
    filesystem = {
        filtered_items = {
            hide_dotfiles = false,
            hide_hidden = false,
            never_show_by_pattern = { ".direnv", ".git", ".*.swp", ".DS_Store" },
            visible = true,
        },
        follow_current_file = { enabled = true, leaveDirsOpen = true },
        use_libuv_file_watcher = vim.fn.has("win32") ~= 1,
    },
    window = { auto_expand_width = false, width = 40 },
})

-- Set up keybinds {{{
do
    local __nixvim_binds = {
        {
            action = function()
                Snacks.terminal()
            end,
            key = "<C-`>",
            mode = { "n", "t" },
            options = { desc = "Toggle terminal" },
        },
        {
            action = function()
                Snacks.scratch()
            end,
            key = "<Leader>.",
            mode = "n",
            options = { desc = "Toggle Scratch Buffer" },
        },
        {
            action = function()
                Snacks.scratch.select()
            end,
            key = "<Leader>S",
            mode = "n",
            options = { desc = "Select Scratch Buffer" },
        },
        {
            action = function()
                Snacks.notifier.hide()
            end,
            key = "<Leader>un",
            mode = "n",
            options = { desc = "Dismiss all notifications" },
        },
        {
            action = function()
                Snacks.lazygit.log_file()
            end,
            key = "<Leader>gf",
            mode = "n",
            options = { desc = "LazyGit file log" },
        },
        {
            action = function()
                Snacks.lazygit()
            end,
            key = "<Leader>gg",
            mode = "n",
            options = { desc = "LazyGit" },
        },
        {
            action = function()
                Snacks.lazygit.log()
            end,
            key = "<Leader>gl",
            mode = "n",
            options = { desc = "LazyGit log" },
        },
        {
            action = function()
                Snacks.gitbrowse.open()
            end,
            key = "<Leader>go",
            mode = "n",
            options = { desc = "Open Git URL" },
        },
        {
            action = function()
                Snacks.git.blame_line()
            end,
            key = "<Leader>gb",
            mode = "n",
            options = { desc = "Git blame for line" },
        },
        {
            action = "<cmd>Neotree action=focus reveal toggle<CR>",
            key = "<leader>e",
            mode = "n",
            options = { desc = "Explorer toggle" },
        },
        { action = "<cmd>Pick files<CR>", key = "<C-Space>", mode = "n", options = { desc = "File picker" } },
        { action = "<cmd>Pick grep_live<CR>", key = "<Leader>/", mode = "n", options = { desc = "Live grep" } },
        {
            action = "<cmd>Pick resume<CR>",
            key = "<Leader><Leader>",
            mode = "n",
            options = { desc = "Resume last picker" },
        },
        { action = "<cmd>Pick files<CR>", key = "<Leader>f", mode = "n", options = { desc = "File picker" } },
        { action = "<Cmd>w<CR>", key = "<Leader>w", mode = "n", options = { desc = "Save" } },
        { action = "<cmd>noh<CR>", key = "<esc>", mode = "n" },
        { action = "y$", key = "Y", mode = "n" },
        { action = "<gv", key = "<", mode = "v", options = { desc = "Unindent line" } },
        { action = "<gv", key = "<S-Tab>", mode = "v", options = { desc = "Unindent line" } },
        { action = ">gv", key = "<Tab>", mode = "v", options = { desc = "Indent line" } },
        { action = ">gv", key = ">", mode = "v", options = { desc = "Indent line" } },
    }
    for i, map in ipairs(__nixvim_binds) do
        vim.keymap.set(map.mode, map.key, map.action, map.options)
    end
end
-- }}}

vim.filetype.add({ extension = { ignore = "gitignore" }, pattern = { ["flake.lock"] = "json" } })

-- Set up autogroups {{
do
    local __nixvim_autogroups = { nixvim_binds_LspAttach = { clear = true } }

    for group_name, options in pairs(__nixvim_autogroups) do
        vim.api.nvim_create_augroup(group_name, options)
    end
end
-- }}
-- Set up autocommands {{
do
    local __nixvim_autocommands = {
        {
            callback = function(args)
                do
                    local __nixvim_binds = {
                        {
                            action = vim.lsp.buf.hover,
                            key = "K",
                            mode = "n",
                            options = { desc = "Lsp buf hover", silent = false },
                        },
                        {
                            action = vim.lsp.buf.references,
                            key = "gD",
                            mode = "n",
                            options = { desc = "Lsp buf references", silent = false },
                        },
                        {
                            action = vim.lsp.buf.definition,
                            key = "gd",
                            mode = "n",
                            options = { desc = "Lsp buf definition", silent = false },
                        },
                        {
                            action = vim.lsp.buf.implementation,
                            key = "gi",
                            mode = "n",
                            options = { desc = "Lsp buf implementation", silent = false },
                        },
                        {
                            action = vim.lsp.buf.type_definition,
                            key = "gt",
                            mode = "n",
                            options = { desc = "Lsp buf type_definition", silent = false },
                        },
                    }

                    for i, map in ipairs(__nixvim_binds) do
                        local options = vim.tbl_extend("keep", map.options or {}, { buffer = args.buf })
                        vim.keymap.set(map.mode, map.key, map.action, options)
                    end
                end
            end,
            desc = "Load keymaps for LspAttach",
            event = "LspAttach",
            group = "nixvim_binds_LspAttach",
        },
        {
            command = "setlocal spell spelllang=en_au,en_gb,en_us",
            event = "FileType",
            pattern = { "markdown", "gitcommit" },
        },
        {
            callback = function()
                vim.b.miniindentscope_disable = true
            end,
            event = { "User" },
            pattern = { "SnacksDashboardOpened" },
        },
    }

    for _, autocmd in ipairs(__nixvim_autocommands) do
        vim.api.nvim_create_autocmd(autocmd.event, {
            group = autocmd.group,
            pattern = autocmd.pattern,
            buffer = autocmd.buffer,
            desc = autocmd.desc,
            callback = autocmd.callback,
            command = autocmd.command,
            once = autocmd.once,
            nested = autocmd.nested,
        })
    end
end
-- }}
