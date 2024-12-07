{
  myLib,
  ...
}:
{
  globals = {
    mapleader = " ";
    maplocalleader = " ";
  };

  keymaps =
    let
      inherit (myLib) modeKeys;
    in
    (modeKeys "n" {
      # Esc to clear search results
      "<esc>" = {
        action = "<cmd>noh<CR>";
      };

      # fix Y behaviour
      "Y" = {
        action = "y$";
      };

      "<Leader>w" = {
        action = "<Cmd>w<CR>"; # Action to perform (save the file in this case)
        options = {
          desc = "Save";
        };
      };
    })
    ++ (modeKeys "v" {
      # Better indenting
      "<S-Tab>" = {
        action = "<gv";
        options = {
          desc = "Unindent line";
        };
      };
      "<" = {
        action = "<gv";
        options = {
          desc = "Unindent line";
        };
      };
      "<Tab>" = {
        action = ">gv";
        options = {
          desc = "Indent line";
        };
      };
      ">" = {
        action = ">gv";
        options = {
          desc = "Indent line";
        };
      };
    });
}
