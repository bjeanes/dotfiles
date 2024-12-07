# https://github.com/folke/snacks.nvim/blob/main/docs/gitbrowse.md
{ myLib, ... }:
{
  plugins.snacks.settings.gitbrowse.enabled = true;

  keymaps =
    let
      inherit (myLib) modeKeys;
    in
    modeKeys "n" {
      "<Leader>go" = {
        action.__raw = ''
          function()
            Snacks.gitbrowse.open()
          end
        '';
        options.desc = "Open Git URL";
      };
    };
}
