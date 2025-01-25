{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:
{
  imports = (lib.snowfall.fs.get-non-default-nix-files-recursive ./zsh-plugins) ++ [
    # TODO make this "module" a common module and include it in system level dot files (tbd if this is inherited in home manager or replaced, so might need to be in both). That way it will be available when `root`, which is handy.
    (
      let
        docker-describe =
          lib.mkBefore # sh
            ''
              # Generic handler to intercept `docker foo` to check if there is a `docker-foo` to call instead.
              # Idea from https://stackoverflow.com/questions/26530234/create-your-own-docker-sub-commands
              docker () {
                if [ $# -eq 0 ]; then
                  command docker
                  return
                fi

                local subcmd="$1"
                shift


                if command -v "docker-$subcmd" >/dev/null 2>&1; then
                  docker-$subcmd "$@"
                else
                  command docker $subcmd "$@"
                fi
              }


              # From https://stackoverflow.com/a/38077377/56690
              # Fucking genius.
              docker-describe() {
                if [ $# -lt 1 ]; then
                  echo "Usage: docker describe CONTAINER"
                  return 1
                fi

                docker inspect --format "$(cat ${inputs.docker-inspect-run-cmd-fmt}/run.tpl)" "$1"
              }
            '';
      in
      {
        programs.zsh.initExtra = docker-describe;
        programs.bash.initExtra = docker-describe;
      }
    )
  ];

  config = {
    home.shellAliases = {
      g = "git";
      l = "ls";
      ll = "ls -la";
      cat = "bat";
      lg = "lazygit";
      cd = "z";
    };

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autocd = true;
      autosuggestion.enable = true;

      plugins = [
      ];
    };
    programs.bash = {
      enable = true;
      enableCompletion = true;
      enableVteIntegration = true;
    };
    programs.starship.enable = true;

    programs.zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };

    programs.eza = {
      enable = true;
      git = true;
      icons = "auto";
      enableBashIntegration = true;
      enableZshIntegration = true;
    };

    # By default, this integration also hooks into shell ^R for history search, but atuin is better
    # and fortunately appears to take precedence when both are enabled
    programs.fzf.enable = true;
    programs.fzf.enableZshIntegration = true;
    programs.fzf.enableBashIntegration = true;
    programs.fzf.fileWidgetOptions = [
      "--preview '${pkgs.bat}/bin/bat --color=always --style=numbers --line-range :500 {}'"
    ];

  };
}
