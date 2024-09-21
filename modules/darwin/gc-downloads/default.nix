{ pkgs, ... }:
{
  config = {
    launchd.user.agents.gc-downloads =
      let
        find = "${pkgs.findutils}/bin/find";
        downloads = "$HOME/Downloads";
        age = "30"; # days
      in
      {
        serviceConfig = {
          ProcessType = "Background";
          RunAtLoad = true;
          StartInterval = 6 * 60 * 60; # every 6 hours
        };

        script = ''
          ${find} ${downloads} -type f -mtime +${age} -print -delete
          ${find} ${downloads} -type d -not -wholename "${downloads}" -empty -print -delete
        '';
      };
  };
}
