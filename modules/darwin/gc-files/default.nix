{ pkgs, ... }:
{
  config =
    let
      find = "${pkgs.findutils}/bin/find";
      age = "30"; # days
    in
    {
      launchd.user.agents.gc-downloads =
        let
          downloads = "$HOME/Downloads";
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

      launchd.user.agents.gc-screenshots =
        let
          desktop = "$HOME/Desktop";
        in
        {
          serviceConfig = {
            ProcessType = "Background";
            RunAtLoad = true;
            StartInterval = 6 * 60 * 60; # every 6 hours
          };

          script = ''
            ${find} ${desktop} -type f -name "Screenshot*.png" -mtime +${age} -print -delete
            ${find} ${desktop} -type d -not -wholename "${desktop}" -empty -print -delete
          '';
        };
    };
}
