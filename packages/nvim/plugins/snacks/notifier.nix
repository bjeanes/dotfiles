{ myLib, ... }:
{
  plugins.snacks = {
    settings = {
      notifier.enabled = true;
    };
  };
  keymaps =
    let
      inherit (myLib) modeKeys;
    in
    modeKeys "n" {
      "<Leader>un" = {
        action.__raw = ''
          function()
            Snacks.notifier.hide()
          end
        '';
        options.desc = "Dismiss all notifications";
      };
    };
}
