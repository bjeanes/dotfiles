{ myLib, ... }:
{
  plugins.snacks = {
    settings = {
      scratch.enabled = true;
    };
  };

  keymaps =
    let
      inherit (myLib) modeKeys;
    in
    modeKeys "n" {
      "<Leader>." = {
        action.__raw = ''
          function()
            Snacks.scratch()
          end
        '';
        options.desc = "Toggle Scratch Buffer";
      };
      "<Leader>S" = {
        action.__raw = ''
          function()
            Snacks.scratch.select()
          end
        '';
        options.desc = "Select Scratch Buffer";
      };
    };
}
