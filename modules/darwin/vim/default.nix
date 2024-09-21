{ ... }: {
  config = {
    # Yank/paste in Neovim to/from macOS clipboard by default
    programs.nixvim.clipboard.register = "unnamedplus";
  };
}
