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
      homelab.tailscale.serve.node.https."/comin" = "http://localhost:4243/metrics";
    })
  ];
}
