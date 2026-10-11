{ inputs, pkgs, ... }:
{
  config =
    let
      devenv = pkgs.devenv;
    in
    {
      home.packages = [ devenv ];

      programs.bash.initExtra = ''
        eval "$(${devenv}/bin/devenv hook bash)"
      '';

      programs.zsh.initContent = ''
        eval "$(${devenv}/bin/devenv hook zsh)"
      '';
    };
}
