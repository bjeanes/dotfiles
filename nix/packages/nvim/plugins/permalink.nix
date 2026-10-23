# Permalinks to the current line or selection on the repo's forge. See
# permalink.lua.
{ lib, myLib, ... }:
{
  extraFiles."lua/permalink.lua".source = ./permalink.lua;

  extraConfigLua = ''
    require("permalink").setup({
      -- Self-hosted forges, by remote host: ["git.example.com"] = { forge = "forgejo" }
      hosts = {
        ["forgejo.griffin-climb.ts.net"] = { forge = "forgejo" }
      },
    })
  '';

  keymaps =
    let
      inherit (myLib) modeKeys;
      # `:` rather than `<Cmd>` so a visual selection becomes the range
      keys = {
        "<Leader>gy" = {
          action = ":PermalinkCopy<CR>";
          options = {
            desc = "Copy permalink";
            silent = true;
          };
        };
        "<Leader>go" = {
          action = ":PermalinkOpen<CR>";
          options = {
            desc = "Open permalink";
            silent = true;
          };
        };
      };
    in
    lib.concatMap (mode: modeKeys mode keys) [
      "n"
      "v"
    ];
}
