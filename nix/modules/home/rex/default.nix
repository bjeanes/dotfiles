{
  flake,
  lib,
  pkgs,
  osConfig ? null,
  ...
}:
let
  tailnet = "griffin-climb.ts.net";
  self = osConfig.networking.hostName or null;

  others = lib.filterAttrs (_: { config, ... }: config.networking.hostName != self);

  # Since a `-bootstrap` config shares its host's hostname, the two collapse into one entry
  byHost =
    endpoint: configurations:
    lib.listToAttrs (
      map (
        { config, ... }:
        lib.nameValuePair config.networking.hostName (endpoint (lib.toLower config.networking.hostName))
      ) (lib.attrValues configurations)
    );

  linuxHosts = byHost (host: "http://${host}.${tailnet}:7297") (
    lib.filterAttrs (_: { config, ... }: config.services.rex.loginServer.enable) (
      others flake.nixosConfigurations
    )
  );

  # The Rex app's built-in Tailscale node, named `<host>-rex` by hand in its settings
  macHosts = byHost (host: "https://${host}-rex.${tailnet}") (others flake.darwinConfigurations);
in
{
  programs.rex = {
    enable = lib.mkDefault pkgs.stdenv.hostPlatform.isDarwin;
    config = lib.concatLines (
      lib.mapAttrsToList (label: endpoint: ''rex.host{ label = "${label}", endpoint = "${endpoint}" }'') (
        linuxHosts // macHosts
      )
    );
  };
}
