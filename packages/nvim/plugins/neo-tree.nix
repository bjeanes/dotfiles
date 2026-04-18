{ config, lib, ... }:
{
  keymaps = lib.mkIf config.plugins.neo-tree.enable [
    {
      mode = "n";
      key = "<leader>e";
      action = "<cmd>Neotree action=focus reveal toggle<CR>";
      options = {
        desc = "Explorer toggle";
      };
    }
  ];

  plugins.neo-tree = {
    enable = true;

    settings = {
      close_if_last_window = true;

      filesystem = {
        use_libuv_file_watcher.__raw = ''vim.fn.has "win32" ~= 1'';

        filtered_items = {
          hide_dotfiles = false;
          hide_hidden = false;

          never_show_by_pattern = [
            ".direnv"
            ".git"
            ".*.swp"
            ".DS_Store"
          ];

          visible = true;
        };

        follow_current_file = {
          enabled = true;
          leave_dirs_open = true;
        };
      };

      window = {
        width = 40;
        auto_expand_width = false;
      };
    };
  };
}
