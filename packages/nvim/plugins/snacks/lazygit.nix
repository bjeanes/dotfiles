{ myLib, ... }:
{
  plugins.snacks = {
    settings = {
      lazygit.enabled = true;
    };
  };

  keymaps =
    let
      inherit (myLib) modeKeys;
    in
    modeKeys "n" {
      "<Leader>gg" = {
        action.__raw = ''
          function()
            Snacks.lazygit()
          end
        '';
        options.desc = "LazyGit";
      };
      "<Leader>gf" = {
        action.__raw = ''
          function()
            Snacks.lazygit.log_file()
          end
        '';
        options.desc = "LazyGit file log";
      };
      "<Leader>gl" = {
        action.__raw = ''
          function()
            Snacks.lazygit.log()
          end
        '';
        options.desc = "LazyGit log";
      };
    };
}
