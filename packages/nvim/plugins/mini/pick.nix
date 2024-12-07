{ myLib, ... }:
{
  plugins.mini = {
    modules = {
      pick = { };
      extra = { };
    };
  };

  keymaps = myLib.modeKeys "n" {
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
  };
}
