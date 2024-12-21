{
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;

    # To match SetEnv config in vcs/default.nix
    extraConfig = ''
      AcceptEnv GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL
    '';
  };
}
