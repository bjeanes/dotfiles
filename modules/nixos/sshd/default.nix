{
  # To match SetEnv config in vcs/default.nix
  services.openssh.extraConfig = ''
    AcceptEnv GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL
  '';
}
