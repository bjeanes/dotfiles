{ config, lib, ... }:
{
  programs.zsh = {
    zsh-abbr.enable = true;
    zsh-abbr.abbreviations =
      with lib;
      config.home.shellAliases
      // config.programs.zsh.shellAliases
      // (concatMapAttrs (n: v: { "git ${n}" = "git ${v}"; }) (
        filterAttrs (n: v: !hasPrefix "!" v) config.programs.git.aliases
      ));
  };
}
