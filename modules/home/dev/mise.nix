{ inputs, pkgs, ... }:
{
  config =
    let
      mise = pkgs.mise;
    in
    {
      home.packages = [ mise ];

      programs.bash.initExtra = /* bash */ ''
        eval "$(${mise}/bin/mise activate bash)"
      '';

      programs.zsh.initContent = /* zsh */ ''
        eval "$(${mise}/bin/mise activate zsh)"
      '';

      programs.zsh.profileExtra = /* zsh */ ''
        # https://mise.jdx.dev/dev-tools/shims.html#how-to-add-mise-shims-to-path
        eval "$(${mise}/bin/mise activate zsh --shims)"
      '';
    };
}
