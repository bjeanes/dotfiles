{
  plugins = {
    treesitter = {
      enable = true;

      folding.enable = false;
      nixvimInjections = true;

      settings = {
        highlight = {
          additional_vim_regex_highlighting = true;
          enable = true;
          disable = # Lua
            ''
              function(lang, bufnr)
                return vim.api.nvim_buf_line_count(bufnr) > 10000
              end
            '';
        };

        incremental_selection = {
          enable = true;
        };

        indent = {
          enable = true;
        };
      };
    };

    treesitter-context = {
      enable = true;
      settings = {
        max_lines = 4;
        min_window_height = 40;
        separator = "-";
      };
    };

    treesitter-refactor = {
      enable = false; # DISABLED https://github.com/nix-community/nixvim/issues/4188#issuecomment-3864805648

      highlightDefinitions = {
        enable = true;
        clearOnCursorMove = true;
      };
      smartRename = {
        enable = true;
      };
      navigation = {
        enable = true;
      };
    };
  };
}
