{
  lib,
  config,
  ...
}:
let
  cfg = config.homelab.services.maintainerr;
in
{
  config = lib.mkIf cfg.enable ({
    virtualisation.oci-containers.containers = {
      maintainerr = {
        # This image is far too coupled to this UID
        user = "1000";
      };
    };
  });
}
