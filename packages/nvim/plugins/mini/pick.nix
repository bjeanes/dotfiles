{ myLib, lib, config, ... }:
let
  enabled = (config.plugins.mini.enable && lib.hasAttr "pick" config.plugins.mini.modules);
in
{
  plugins.mini = {
    modules = {
      pick = { };
      extra = { };
    };

    luaConfig.post = lib.mkIf enabled # lua
      ''
        vim.ui.select = require('mini.pick').ui_select
      '';
  };

  keymaps = lib.mkIf enabled
    (myLib.modeKeys "n" {
      "<Leader>/" = {
        action = "<cmd>Pick grep_live<CR>";
        options.desc = "Live grep";
      };
      "<C-Space>" = {
        action = "<cmd>Pick files<CR>";
        options.desc = "File picker";
      };
      "<Leader><Leader>" = {
        action = "<cmd>Pick resume<CR>";
        options.desc = "Resume last picker";
      };
    });
}
