# A dashboard of the whole homelab: every host lists what it runs, and the
# host with the dashboard gathers those lists from the rest of the flake.
{
  config,
  lib,
  flake,
  ...
}:
let
  cfg = config.homelab.dashboard;
  inherit (config.homelab.tailscale) tailnet;

  entryOptions =
    { name, ... }:
    {
      options = {
        title = lib.mkOption {
          default = name;
          type = lib.types.str;
        };

        group = lib.mkOption {
          default = "Services";
          type = lib.types.str;
        };

        href = lib.mkOption {
          type = lib.types.str;
        };

        icon = lib.mkOption {
          default = null;
          type = lib.types.nullOr lib.types.str;
        };

        description = lib.mkOption {
          default = null;
          type = lib.types.nullOr lib.types.str;
        };
      };
    };

  # This host's own entries come from its config; evaluating it again
  # through the flake would only repeat the work
  otherHosts = removeAttrs flake.nixosConfigurations [ config.networking.hostName ];
  allEntries =
    lib.attrValues cfg.entries
    ++ lib.concatMap (host: lib.attrValues (host.config.homelab.dashboard.entries or { })) (
      lib.attrValues otherHosts
    );

  # Homepage's services.yaml: a list of single-key groups, each a list of
  # single-key services
  servicesYaml = lib.mapAttrsToList (group: entries: {
    ${group} = map (entry: {
      ${entry.title} = lib.filterAttrs (_: v: v != null) {
        inherit (entry) href icon description;
      };
    }) (lib.sortOn (entry: entry.title) entries);
  }) (lib.groupBy (entry: entry.group) allEntries);
in
{
  options.homelab.dashboard = {
    enable = lib.mkEnableOption "the homelab dashboard on this host";

    hostName = lib.mkOption {
      default = "home";
      type = lib.types.str;
      description = "Tailscale Service name the dashboard is served as";
    };

    port = lib.mkOption {
      default = 8090;
      type = lib.types.port;
      description = "Port on 127.0.0.1 the dashboard listens on";
    };

    entries = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule entryOptions);
      description = ''
        What this host contributes to the dashboard. Services with a tailnet
        hostName are added automatically; anything else can be added here.
      '';
    };
  };

  config = lib.mkMerge [
    {
      homelab.dashboard.entries =
        lib.mapAttrs
          (_: service: {
            href = "https://${service.hostName}.${tailnet}${service.dashboard.path}";
            inherit (service.dashboard) group icon description;
          })
          (lib.filterAttrs (_: s: s ? dashboard && s.enable && s.dashboard.enable) config.homelab.services);
    }

    (lib.mkIf cfg.enable {
      services.homepage-dashboard = {
        enable = true;
        listenPort = cfg.port;
        allowedHosts = "${cfg.hostName}.${tailnet}";
        settings.title = "Homelab";
        services = servicesYaml;
      };

      homelab.tailscale.serve.services.${cfg.hostName} = {
        https = cfg.port;
        displayName = "homepage";
      };
    })
  ];
}
