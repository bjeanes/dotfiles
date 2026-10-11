{ pkgs, ... }:
let
  filetypes = [
    "clojure"
    "fennel"
    "janet"
    "lisp"
    "racket"
    "scheme"
  ];
in
{
  # Structural editing: slurp/barf (`>)` `<)`), drag (`>e` `>f`), raise
  # (`<LocalLeader>o`), splice (`<LocalLeader>@`), element motions (`W` `B`
  # `E`), and form/element text objects (`af` `if` `ae` `ie`).
  extraPlugins = [ pkgs.vimPlugins.nvim-paredit ];
  extraConfigLua = ''
    require("nvim-paredit").setup({ indent = { enabled = true } })
  '';

  # REPL. Defaults cover many non-Lisps (Ruby, Rust, Elixir, …), so narrow them.
  plugins.conjure.enable = true;
  globals = {
    "conjure#filetypes" = filetypes;

    # We get these from LSP already and the mappings this would use I am already using for the LSP version of the same
    # functionality
    "conjure#mapping#doc_word" = false;
    "conjure#mapping#def_word" = false;
  };

  plugins.rainbow-delimiters = {
    enable = true;
    settings.whitelist = [
      "clojure"
      "commonlisp"
      "fennel"
      "janet_simple"
      "racket"
      "scheme"
    ];
  };

  # ' and ` are reader macros here so re-define the keymaps to override the autopair behaviour from mini.pairs.
  autoCmd = [
    {
      event = "FileType";
      pattern = filetypes;
      callback.__raw = ''
        function(args)
          for _, key in ipairs({ "'", "`" }) do
            vim.keymap.set("i", key, key, { buffer = args.buf })
          end
        end
      '';
    }
  ];
}
