{ lib, pkgs, ... }:
{
  plugins.conform-nvim = {
    enable = true;

    luaConfig.pre = # lua
      ''
        local slow_format_filetypes = {}
      '';

    # TODO: Can this be handled by https://github.com/folke/snacks.nvim/blob/main/docs/toggle.md?
    luaConfig.content = # lua
      ''
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
      '';

    settings = {
      default_format_opts.lsp_format = "last";

      format_on_save = # Lua
        ''
          function(bufnr)
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
           end
        '';

      format_after_save = # Lua
        ''
          function(bufnr)
            if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
              return
            end

            if not slow_format_filetypes[vim.bo[bufnr].filetype] then
              return
            end

            return { lsp_format = "last" }
          end
        '';

      # NOTE:
      # Conform will run multiple formatters sequentially
      # [ "1" "2" "3"]
      # Add stop_after_first to run only the first available formatter
      # { "__unkeyed-1" = "foo"; "__unkeyed-2" = "bar"; stop_after_first = true; }
      # Use the "*" filetype to run formatters on all filetypes.
      # Use the "_" filetype to run formatters on filetypes that don't
      # have other formatters configured.
      formatters_by_ft = {
        bash = [
          "shellcheck"
          "shellharden"
          "shfmt"
        ];
        css = [ "stylelint" ];
        javascript = {
          __unkeyed-1 = "biome";
          __unkeyed-2 = "prettierd";
          timeout_ms = 2000;
          stop_after_first = true;
        };
        json = [ "jq" ];
        lua = [ "stylua" ];
        markdown = [
          "injected"
          "mdformat"
        ];
        nix = [ "nixfmt" ];
        rust = [ "rustfmt" ];
        sh = [
          "shellcheck"
          "shellharden"
          "shfmt"
        ];
        sql = [ "sqlfluff" ];
        terraform = [ "terraform_fmt" ];
        toml = [ "taplo" ];
        typescript = {
          __unkeyed-1 = "biome";
          __unkeyed-2 = "prettierd";
          timeout_ms = 2000;
          stop_after_first = true;
        };
        xml = [
          "xmlformat"
          "xmllint"
        ];
        yaml = [ "yamlfmt" ];
        "_" = [
          "trim_whitespace"
          "trim_newlines"
        ];
      };

      formatters = {
        biome = {
          command = lib.getExe pkgs.biome;
        };
        jq = {
          command = lib.getExe pkgs.jq;
        };
        nixfmt = {
          command = lib.getExe pkgs.nixfmt-rfc-style;
        };
        mdformat =
          let
            pyPkgs = pkgs.python312Packages;
          in
          {
            command = lib.getExe (pkgs.writeShellApplication {
              name = "mdformat";

              runtimeInputs = [
                pyPkgs.mdformat
                pyPkgs.mdformat-tables
                pyPkgs.mdformat-gfm
                pyPkgs.mdformat-gfm-alerts
                pyPkgs.mdformat-frontmatter
                # pyPkgs.mdformat-obsidian
              ];

              text = ''
                mdformat "$@"
              '';
            });
          };
        prettierd = {
          command = lib.getExe pkgs.prettierd;
        };
        rustfmt = {
          command = lib.getExe pkgs.rustfmt;
        };
        shellcheck = {
          command = lib.getExe pkgs.shellcheck;
        };
        shfmt = {
          command = lib.getExe pkgs.shfmt;
        };
        shellharden = {
          command = lib.getExe pkgs.shellharden;
        };
        sqlfluff = {
          command = lib.getExe pkgs.sqlfluff;
        };
        stylelint = {
          command = lib.getExe pkgs.stylelint;
        };
        stylua = {
          command = lib.getExe pkgs.stylua;
        };
        taplo = {
          command = lib.getExe pkgs.taplo;
        };
        terraform_fmt = {
          command = lib.getExe pkgs.terraform;
        };
        xmlformat = {
          command = lib.getExe pkgs.xmlformat;
        };
        yamlfmt = {
          command = lib.getExe pkgs.yamlfmt;
        };
      };
    };
  };
}
