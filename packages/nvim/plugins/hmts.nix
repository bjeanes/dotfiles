# Often in a nix configuration, and in particular with home manager, you find
# yourself inlining files in arbitrary languages as strings. This, by default,
# gets highlighted as a plain, boring string. This plugin uses treesitter
# queries to inject the actual language used within the screen, enabling proper
# highlighting of the language within.
#
# https://github.com/calops/hmts.nvim
{
  plugins = {
    hmts = {
      enable = true;
    };
  };
}
