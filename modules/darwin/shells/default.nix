{ ... }: {
  config = {
    # ZSH needs to be here in addition to the home-manager configuration below in order to write /etc/zshenv to correctly configure ZSH. This is confusing, but...
    # https://github.com/LnL7/nix-darwin/issues/1003
    # https://github.com/LnL7/nix-darwin/issues/922#issuecomment-2041430035
    programs.zsh.enable = true;

    programs.bash.enable = true;
  };
}
