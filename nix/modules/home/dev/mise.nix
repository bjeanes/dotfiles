{
  inputs,
  lib,
  pkgs,
  ...
}:
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

      # Last, so the shims win over anything else that prepends to PATH (e.g. Homebrew)
      programs.zsh.profileExtra = lib.mkAfter /* zsh */ ''
        # https://mise.jdx.dev/dev-tools/shims.html#how-to-add-mise-shims-to-path
        eval "$(${mise}/bin/mise activate zsh --shims)"
      '';
    };
}
