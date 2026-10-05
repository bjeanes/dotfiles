{
  lib,
  pkgs,
  myLib,
  ...
}:
{
  # Real Claude Code TUI (in a snacks terminal split) speaking the same IDE
  # protocol as the official VS Code/JetBrains extensions: selection context,
  # native diff review, etc. Uses whatever `claude` is logged in to (i.e. plan
  # billing, not API).
  plugins.claudecode = {
    enable = true;
    settings = {
      terminal.provider = "snacks";
    };
  };

  dependencies.claude-code.enable = false;

  # Native chat buffer driving any ACP agent (Claude Code, OpenCode, Codex, ...)
  # plus plain HTTP adapters for local models in LM Studio.
  plugins.codecompanion = {
    enable = true;
    settings = {
      adapters = {
        http.lmstudio.__raw = # lua
          ''
            function()
              return require("codecompanion.adapters").extend("openai_compatible", {
                name = "lmstudio",
                formatted_name = "LM Studio",
                env = {
                  url = "http://localhost:1234",
                  api_key = "lm-studio",
                },
              })
            end
          '';

        # Token comes from $CLAUDE_CODE_OAUTH_TOKEN if set, else the agenix
        # secret (see secrets/secrets.nix), so it needn't be exported to every
        # shell and is only ever handed to the agent process. The
        # stock adapter would also fall back to the literal string
        # "CLAUDE_CODE_OAUTH_TOKEN" when unset (401), and its auth handler
        # copies the token into nvim's own env (inherited by :terminal etc).
        # Without the secret, the agent uses the regular `claude` login.
        acp.claude_code.__raw = # lua
          ''
            function()
              return require("codecompanion.adapters").extend("claude_code", {
                -- Absolute path: direnv reloads inside nvim reset $PATH to the
                -- pre-direnv shell's, dropping the nixvim wrapper's entries.
                commands = {
                  default = { "${lib.getExe pkgs.claude-agent-acp}" },
                  yolo = { "${lib.getExe pkgs.claude-agent-acp}", "--yolo" },
                },
                env = {
                  CLAUDE_CODE_OAUTH_TOKEN = function()
                    local token = vim.env.CLAUDE_CODE_OAUTH_TOKEN
                    if token and token ~= "" then
                      return token
                    end
                    local ok, lines = pcall(vim.fn.readfile, "/run/agenix/claude-code-oauth-token")
                    token = ok and vim.trim(table.concat(lines, "")) or ""
                    return token ~= "" and token or nil
                  end,
                },
                handlers = {
                  -- env_replaced is passed to the agent process; nothing to export.
                  auth = function(self)
                    return self.env_replaced.CLAUDE_CODE_OAUTH_TOKEN ~= nil
                  end,
                },
              })
            end
          '';
      };

      interactions = {
        # Agentic chat defaults to Claude Code over ACP; switch adapter in the
        # chat buffer with `ga` (e.g. to `opencode` for local models).
        chat.adapter = "claude_code";
        # Inline/cmd/background need an HTTP adapter, so these go local.
        inline.adapter = "lmstudio";
        cmd.adapter = "lmstudio";
        background.adapter = "lmstudio";
      };
    };
  };

  plugins.which-key.settings.spec = [
    {
      __unkeyed-1 = "<Leader>a";
      group = "AI";
    }
  ];

  keymaps =
    let
      inherit (myLib) modeKeys;
      cmd = c: "<Cmd>${c}<CR>";
    in
    (modeKeys "n" {
      # Claude Code
      "<Leader>ac" = {
        action = cmd "ClaudeCode";
        options.desc = "Toggle Claude Code";
      };
      "<Leader>af" = {
        action = cmd "ClaudeCodeFocus";
        options.desc = "Focus Claude Code";
      };
      "<Leader>ar" = {
        action = cmd "ClaudeCode --resume";
        options.desc = "Resume Claude Code session";
      };
      "<Leader>ab" = {
        action = cmd "ClaudeCodeAdd %";
        options.desc = "Add buffer to Claude Code";
      };
      "<Leader>ay" = {
        action = cmd "ClaudeCodeDiffAccept";
        options.desc = "Accept Claude Code diff";
      };
      "<Leader>an" = {
        action = cmd "ClaudeCodeDiffDeny";
        options.desc = "Reject Claude Code diff";
      };

      # CodeCompanion
      "<Leader>ai" = {
        action = cmd "CodeCompanionChat Toggle";
        options.desc = "Toggle CodeCompanion chat";
      };
      "<Leader>ap" = {
        action = cmd "CodeCompanionActions";
        options.desc = "CodeCompanion actions";
      };
      # Review the agent's edits as quickfix hunks; send comments back to the
      # chat agent with `#{code_review}`.
      "<Leader>aR" = {
        action = cmd "CodeCompanionCodeReview";
        options.desc = "Review agent changes";
      };
      "<Leader>aC" = {
        action = cmd "CodeCompanionCodeReview Comment";
        options.desc = "Comment on agent change";
      };
    })
    ++ (modeKeys "v" {
      "<Leader>aC" = {
        action = ":CodeCompanionCodeReview Comment<CR>";
        options.desc = "Comment on agent change";
      };
      "<Leader>as" = {
        action = cmd "ClaudeCodeSend";
        options.desc = "Send selection to Claude Code";
      };
      "<Leader>ai" = {
        action = cmd "CodeCompanionChat Add";
        options.desc = "Add selection to CodeCompanion chat";
      };
      "<Leader>ap" = {
        action = cmd "CodeCompanionActions";
        options.desc = "CodeCompanion actions";
      };
    });
}
