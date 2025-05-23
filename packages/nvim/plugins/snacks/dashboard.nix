{ config, lib, ...}: {
  plugins.snacks = {
    settings.dashboard = {
      enabled = true;

      preset = {
        # Not sure why but I have to intentionally unindent the first 2 lines
        # for this to look right inside snacks' dashboard
        header = builtins.readFile ./../../splash.raw;

        keys = [
          {
            icon = " ";
            key = "f";
            desc = "Find File";
            action = ":Pick files";
          }
          {
            icon = " ";
            key = "n";
            desc = "New File";
            action = ":ene | startinsert";
          }
          {
            icon = " ";
            key = "g";
            desc = "Find Text";
            action = ":Pick grep_live";
          }
          {
            icon = " ";
            key = "r";
            desc = "Recent Files";
            action = ":Pick oldfiles";
          }
          {
            icon = " ";
            key = "c";
            desc = "Config";
            action = '':lua Snacks.dashboard.pick('files', {cwd = "${builtins.toString ./../..}"})'';
          }
          {
            icon = " ";
            key = "s";
            desc = "Restore Session";
            section = "session";
          }
          {
            icon = " ";
            key = "q";
            desc = "Quit";
            action = ":qa";
          }
        ];
      };

      sections = [
        { section = "header"; }
        {
          section = "keys";
          title = "Keymaps";
          indent = 2;
          #gap = 1;
          padding = 2;
        }
        {
          # pane = 2;
          icon = " ";
          title = "Recent Files";
          section = "recent_files";
          indent = 2;
          padding = 2;
          # padding = [
          #   0
          #   13
          # ];
        }
        {
          # pane = 2;
          icon = " ";
          title = "Projects";
          section = "projects";
          indent = 2;
          padding = 2;
        }
      ];
    };
  };

  autoCmd = lib.mkIf (config.plugins.snacks.settings.dashboard.enabled && config.plugins.mini.enable && lib.hasAttr "indentscope" config.plugins.mini.modules)
    [
      {
        event = [ "User" ];
        pattern = [
          "SnacksDashboardOpened"
        ];
        callback.__raw = ''
          function()
            vim.b.miniindentscope_disable = true
          end
        '';
      }
    ];
}
