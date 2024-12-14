{
  plugins.which-key.enable = true;

  plugins.mini = {
    enable = true;
    modules = {
      # https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-cursorword.md
      cursorword = { };

      # Preserve window layout when removing a buffer
      #
      # https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-bufremove.md
      bufremove = { };
    };
  };
}
