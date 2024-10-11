{ inputs, system, ... }: {
  config =
    let
      mise = inputs.mise.packages.${system}.mise;
    in
    {
      home.packages = [ mise ];

      programs.bash.initExtra = ''
        eval "$(${mise}/bin/mise activate bash)"
      '';

      programs.zsh.initExtra = ''
        eval "$(${mise}/bin/mise activate zsh)"
      '';
    };
}
