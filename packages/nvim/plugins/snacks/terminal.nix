{ myLib, ... }:
{
  plugins.snacks = {
    settings = {
      terminal.enabled = true;
    };
  };

  keymaps =
    let
      inherit (myLib) modeKeys;
    in
    modeKeys
      [
        "n"
        "t"
      ]
      {
        "<C-`>" = {
          action.__raw = ''
            function()
              Snacks.terminal()
            end
          '';
          options.desc = "Toggle terminal";
        };
      };
}
