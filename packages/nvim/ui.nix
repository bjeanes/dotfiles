{
  plugins.which-key.enable = true;

  plugins.mini = {
    enable = true;
    modules = {
      animate = {
        cursor.enable = false;

        # https://github.com/echasnovski/mini.nvim/issues/357#issuecomment-1578277149
        open.enable = false;
        close.enable = false;
      };

      # https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-cursorword.md
      cursorword = { };

      # Preserve window layout when removing a buffer
      #
      # https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-bufremove.md
      bufremove = { };
    };
  };
}
