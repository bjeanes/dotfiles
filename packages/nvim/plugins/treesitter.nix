{
  plugins = {
    treesitter = {
      enable = true;

      folding = false;
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
      enable = true;

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
