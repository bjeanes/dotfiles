{
  services.comin = {
    enable = true;
    remotes = [{
      name = "origin";
      url = "https://githuib.com/bjeanes/dotfiles.git";
      branches.main.name = "main";
    }];
  };
}
