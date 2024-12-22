{
  services.comin = {
    enable = true;
    remotes = [
      {
        name = "origin";
        url = "https://github.com/bjeanes/dotfiles.git";
        branches.main.name = "main";
      }
    ];
  };
}
