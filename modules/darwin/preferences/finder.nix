{
  # https://mynixos.com/nix-darwin/options/system.defaults.finder
  system.defaults.finder = {
    # Show file extensions in Finder
    AppleShowAllExtensions = true;

    # Default to column view in Finder
    FXPreferredViewStyle = "clmv";

    # Allow quitting Finder from the menu
    QuitMenuItem = true;

    ShowPathbar = true;
    ShowStatusBar = true;
  };

  system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
  system.defaults.NSGlobalDomain.NSNavPanelExpandedStateForSaveMode = true;
  system.defaults.NSGlobalDomain.NSNavPanelExpandedStateForSaveMode2 = true;
}
