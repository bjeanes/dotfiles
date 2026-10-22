-- Example project config for container_lsp.lua. Copy it to
-- `<project>/.nvim/container-lsp.lua` and adjust. Neovim asks to trust it the
-- first time it's read, and again whenever it changes.
--
-- Only servers passed to `require("container_lsp").setup({ ... })` in the
-- Neovim config are considered. Servers and roots not listed here fall back to
-- the server's stock host config.
return {
  -- Optional; defaults to { "docker", "compose" }. Run from the directory
  -- containing `.nvim/`, so relative paths resolve against the project root.
  -- Name the file explicitly when the environment (e.g. a direnv-loaded
  -- COMPOSE_FILE) isn't reliably set where Neovim was started.
  compose = { "docker", "compose", "--file", "compose.yml" },

  -- Keyed by the server's name in vim.lsp.config.
  servers = {
    ruby_lsp = {
      -- Runs inside the container, from the LSP root's path there. stdout is
      -- the protocol stream, so anything else a wrapper prints must go to
      -- stderr.
      cmd = { "bundle", "exec", "ruby-lsp" },

      -- LSP root (relative to the project root; "." for the root itself) ->
      -- the Compose service to run it in. The root comes from the server's
      -- usual root detection (for ruby_lsp, the nearest Gemfile), so list the
      -- directories that detection lands on. A stopped service is started.
      services = {
        ["."] = "web",
        ["engines/billing"] = "billing",
      },
    },

    -- A tool that serves the whole project from one service, e.g. a linter
    -- image with the repo mounted.
    rubocop = {
      cmd = { "rubocop", "--lsp" },
      -- "*" matches any root in the project not listed explicitly
      services = { ["*"] = "lints" },
    },
  },
}
