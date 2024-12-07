{
  colorschemes.catppuccin = {
    enable = true;
    settings = {
      default_integrations = true;

      flavour = "macchiato";

      # https://github.com/catppuccin/nvim/tree/main/lua/catppuccin/groups/integrations
      integrations = {
        cmp = true;
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
