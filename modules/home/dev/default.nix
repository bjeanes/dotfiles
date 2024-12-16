{ pkgs, lib, ... }:
{
  imports = (lib.snowfall.fs.get-non-default-nix-files-recursive ./.);

  config = {
    home.packages = with pkgs; [
      git
      git-absorb # https://github.com/tummychow/git-absorb
      mkcert
      bat
      treefmt
      direnv
      nixpkgs-fmt
      nil
      snowfallorg.flake
      jq
    ];

    # TODO: https://news.ycombinator.com/item?id=31010090 for wiring together `rg`+`fzf`+`bat`
    programs.ripgrep.enable = true;

    programs.bat.enable = true;
    programs.bat.config = {
      map-syntax = [
        "flake.lock:JSON"
      ];
    };

    programs.direnv = {
      enable = true;
      config.global.hide_env_diff = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
      nix-direnv.enable = true;
    };

    programs.gh.enable = true;
    programs.gh.settings.aliases = {
      # https://cli.github.com/manual/gh_alias_set
      configure-repo-squash = "api repos/{owner}/{repo} --method PATCH -f allow_squash_merge=true -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY";
      configure-repo-delete-merged = "api repos/{owner}/{repo} --method PATCH -f delete_branch_on_merge=true";
      configure-repo = "!gh configure-repo-squash && gh configure-repo-delete-merged";
    };
  };
}
