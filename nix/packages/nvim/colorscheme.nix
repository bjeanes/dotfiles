{
  colorschemes.catppuccin = {
    enable = true;
    settings = {
      default_integrations = true;

      # Neovim sets 'background' from the terminal's background colour, and
      # updates it when the terminal reports a theme change (DEC mode 2031).
      flavour = "auto";
      background = {
        light = "latte";
        dark = "macchiato";
      };

      # https://github.com/catppuccin/nvim/tree/main/lua/catppuccin/groups/integrations
      integrations = {
        blink_cmp = true;
        mini.enabled = true;
        treesitter = true;
      };

      term_colors = true;
      transparent_background = true;
    };
  };

  # https://github.com/catppuccin/nvim/issues/412#issuecomment-1436665964
  opts = {
    winblend = 0;
    pumblend = 0;
  };
}
