{ config, lib, ... }:
{
  imports = [
    {
      services.comin = {
        enable = true;
        remotes = [
          {
            name = "origin";
            url = "https://github.com/bjeanes/dotfiles.git";
            branches.main.name = "main";
          }
        ];
      };
    }

    (lib.mkIf config.services.tailscale.enable {
      system.activationScripts = {
        tsServeComin.text = # sh
          ''
            ${config.services.tailscale.package}/bin/tailscale serve --bg --set-path "/comin" "http://localhost:4242/status"
          '';
      };
    })
  ];
}
