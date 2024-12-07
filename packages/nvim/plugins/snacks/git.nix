{ myLib, ... }:
{
  plugins.snacks = {
    settings = {
      git.enabled = true;
    };
  };
  keymaps =
    let
      inherit (myLib) modeKeys;
    in
    modeKeys "n" {
      "<Leader>gb" = {
        action.__raw = ''
          function()
            Snacks.git.blame_line()
          end
        '';
        options.desc = "Git blame for line";
      };
    };
}
