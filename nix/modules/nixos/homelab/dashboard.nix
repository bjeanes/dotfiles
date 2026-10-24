# A dashboard of the whole homelab: every host lists what it runs, and the
# host with the dashboard gathers those lists from the rest of the flake.
{
  config,
  lib,
  pkgs,
  flake,
  ...
}:
let
  cfg = config.homelab.dashboard;
  inherit (config.homelab.tailscale) tailnet;

  widgetOptions = {
    options = {
      type = lib.mkOption {
        type = lib.types.str;
        description = "Homepage widget type, e.g. `sonarr`";
      };

      url = lib.mkOption {
        default = null;
        type = lib.types.nullOr lib.types.str;
        description = "URL the widget queries; defaults to the entry's origin";
      };

      secrets = lib.mkOption {
        default = { };
        type = lib.types.attrsOf lib.types.str;
        example = {
          key = "sonarr-api-key";
        };
        description = "Widget fields filled from agenix secrets, by secret name";
      };

      settings = lib.mkOption {
        default = { };
        type = lib.types.attrsOf lib.types.anything;
        description = "Any other widget fields";
      };
    };
  };

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

        widget = lib.mkOption {
          default = null;
          type = lib.types.nullOr (lib.types.submodule widgetOptions);
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

  /*
    Widget keys reach Homepage as systemd credentials, which it reads through
    `{{HOMEPAGE_FILE_*}}`. A widget is only shown once every secret it needs
    exists on this host, so adding the secret is all it takes to switch it on.
  */
  secretEnv = secret: "HOMEPAGE_FILE_${lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] secret)}";
  widgetReady =
    entry:
    entry.widget != null
    && lib.all (secret: config.age.secrets ? ${secret}) (lib.attrValues entry.widget.secrets);
  readyEntries = lib.filter widgetReady allEntries;
  widgetSecrets = lib.unique (
    lib.concatMap (entry: lib.attrValues entry.widget.secrets) readyEntries
  );

  origin = href: lib.head (builtins.match "(https?://[^/]+).*" href);
  renderWidget =
    entry:
    let
      inherit (entry) widget;
    in
    {
      inherit (widget) type;
      url = if widget.url != null then widget.url else origin entry.href;
    }
    // widget.settings
    // lib.mapAttrs (_: secret: "{{${secretEnv secret}}}") widget.secrets;

  # Homepage's services.yaml: a list of single-key groups, each a list of
  # single-key services
  servicesYaml = lib.mapAttrsToList (group: entries: {
    ${group} = map (entry: {
      ${entry.title} = lib.filterAttrs (_: v: v != null) {
        inherit (entry) href icon description;
        widget = if widgetReady entry then renderWidget entry else null;
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
      homelab.dashboard.entries = lib.mapAttrs (
        _: service:
        let
          base = "https://${service.hostName}.${tailnet}";
          inherit (service.dashboard) widget;
        in
        {
          href = "${base}${service.dashboard.path}";
          inherit (service.dashboard) group icon description;
          # The widget queries the app where the entry links, without the
          # trailing slash Homepage would double up
          widget =
            if widget == null then
              null
            else
              { url = "${base}${lib.removeSuffix "/" service.dashboard.path}"; } // widget;
        }
      ) (lib.filterAttrs (_: s: s ? dashboard && s.enable && s.dashboard.enable) config.homelab.services);
    }

    (lib.mkIf cfg.enable {
      # Outside Nix altogether
      homelab.dashboard.entries = {
        unifi = {
          title = "UniFi";
          group = "Network";
          href = "https://10.10.10.254";
          icon = "unifi.png";
          description = "Home network and Wi-Fi";
          widget = {
            type = "unifi";
            secrets.key = "unifi-api-key";
          };
        };

        nextdns = {
          title = "NextDNS";
          group = "Network";
          href = "https://my.nextdns.io";
          icon = "nextdns.png";
          description = "Blocks ads and trackers for the whole network";
          widget = {
            type = "nextdns";
            # The profile ID too: it's enough to use the profile as a resolver
            secrets = {
              key = "nextdns-api-key";
              profile = "nextdns-profile";
            };
          };
        };
      };

      services.homepage-dashboard = {
        enable = true;
        listenPort = cfg.port;
        allowedHosts = "${cfg.hostName}.${tailnet}";
        settings.title = "Homelab";
        services = servicesYaml;
      };

      /*
        Homepage pastes a secret file into its YAML verbatim before parsing it,
        so a trailing newline (as editors leave) breaks the whole file. These
        trimmed copies are what it loads instead; credentials are read before
        the unit's own commands run, so the trimming has to happen first.
      */
      systemd.services.homepage-dashboard-secrets = lib.mkIf (widgetSecrets != [ ]) {
        description = "Trimmed secrets for Homepage widgets";
        before = [ "homepage-dashboard.service" ];
        requiredBy = [ "homepage-dashboard.service" ];
        partOf = [ "homepage-dashboard.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          RuntimeDirectory = "homepage-dashboard-secrets";
          RuntimeDirectoryMode = "0700";
          UMask = "0077";
        };
        script = lib.concatMapStrings (secret: ''
          ${pkgs.coreutils}/bin/tr -d '\r\n' \
            < ${lib.escapeShellArg config.age.secrets.${secret}.path} \
            > "$RUNTIME_DIRECTORY"/${lib.escapeShellArg secret}
        '') widgetSecrets;
      };

      systemd.services.homepage-dashboard = {
        # The paths it reads secrets from never change, so it would otherwise
        # keep a secret's old value; restarting it re-trims them too (partOf)
        restartTriggers = map (secret: config.age.secrets.${secret}.file) widgetSecrets;
        environment = lib.listToAttrs (
          map (secret: lib.nameValuePair (secretEnv secret) "%d/${secret}") widgetSecrets
        );
        serviceConfig.LoadCredential = map (
          secret: "${secret}:/run/homepage-dashboard-secrets/${secret}"
        ) widgetSecrets;
      };

      homelab.tailscale.serve.services.${cfg.hostName} = {
        https = cfg.port;
        displayName = "homepage";
      };
    })
  ];
}
