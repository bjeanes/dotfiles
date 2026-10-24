# Tailscale Serve on this machine's own tailscaled. Services hosted here are an
# alternative to a sidecar node per service.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.tailscale.serve.services;
  nodeCfg = config.homelab.tailscale.serve.node;
  tailscale = lib.getExe config.services.tailscale.package;

  # "/" -> "root", "/foo/bar" -> "foo-bar"
  pathUnitName =
    path:
    let
      name = lib.concatStringsSep "-" (lib.filter (s: s != "") (lib.splitString "/" path));
    in
    "tailscale-serve-node-${if name == "" then "root" else name}";

  upstream =
    scheme: target:
    if builtins.isInt target then "${scheme}://127.0.0.1:${toString target}" else target;

  target =
    with lib.types;
    either port (strMatching "[a-z+]+://.+")
    // {
      description = "port on 127.0.0.1, or URL";
    };

  serviceOptions = {
    options = {
      https = lib.mkOption {
        default = null;
        type = lib.types.nullOr target;
        example = 3000;
        description = ''
          Upstream for HTTPS on port 443. tailscaled terminates TLS, so a bare
          port is proxied to as plain HTTP.
        '';
      };

      tcp = lib.mkOption {
        default = { };
        type = lib.types.attrsOf target;
        example = {
          "22" = 2222;
        };
        description = "Raw TCP forwards, keyed by listen port";
      };

      tlsTcp = lib.mkOption {
        default = { };
        type = lib.types.attrsOf target;
        example = {
          "6697" = 6501;
        };
        description = "TCP forwards that tailscaled terminates TLS for, keyed by listen port";
      };
    };
  };

  /*
    `serve set-config` would be declarative, but its versioned file ties the
    listener to the upstream scheme: `http://` serves plain HTTP and `https://`
    proxies to a TLS backend, so TLS on 443 in front of a plain HTTP app can't
    be written there. The CLI flags can say it.

    Once https://github.com/tailscale/tailscale/issues/18381 is fixed, the aim
    is a single declarative `set-config --all` (or whatever the NixOS
    tailscale module grows for it) in place of these units.
  */
  serveCommands =
    name: service:
    let
      svc = lib.escapeShellArg "svc:${name}";
      serve =
        flag: listen: to:
        "${tailscale} serve --service=${svc} --${flag}=${listen} ${to}";
    in
    lib.optional (service.https != null) (serve "https" "443" (upstream "http" service.https))
    ++ lib.mapAttrsToList (listen: to: serve "tcp" listen (upstream "tcp" to)) service.tcp
    ++ lib.mapAttrsToList (
      listen: to: serve "tls-terminated-tcp" listen (upstream "tcp" to)
    ) service.tlsTcp;

  mkOneshot = description: serviceConfig: {
    inherit description;
    after = [
      "tailscaled.service"
      "tailscaled-autoconnect.service"
    ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # The node may not be logged in yet on first boot
      Restart = "on-failure";
      RestartSec = "10s";
    }
    // serviceConfig;
  };

  mkServiceUnit =
    name: service:
    let
      clear = "${tailscale} serve clear ${lib.escapeShellArg "svc:${name}"}";
    in
    # Clearing first drops listeners that are no longer configured. Stopping
    # un-advertises, so removing the service from the config takes it off the
    # tailnet.
    mkOneshot "Tailscale Service svc:${name}" {
      ExecStart = pkgs.writeShellScript "tailscale-service-${name}" ''
        set -euo pipefail
        ${clear}
        ${lib.concatStringsSep "\n" (serveCommands name service)}
      '';
      ExecStop = clear;
    };

  # Setting a path replaces its handler, so unlike services there is nothing
  # to clear first. `off` fails if the handler is already gone, hence `-`.
  mkNodeUnit =
    path: to:
    let
      serve = "${tailscale} serve --https=443 --set-path=${lib.escapeShellArg path}";
    in
    mkOneshot "Tailscale Serve ${path} on this node" {
      ExecStart = "${serve} --bg ${lib.escapeShellArg (upstream "http" to)}";
      ExecStop = "-${serve} off";
    };
in
{
  options.homelab.tailscale.serve = {
    node.https = lib.mkOption {
      default = { };
      type = lib.types.attrsOf target;
      example = {
        "/metrics" = 9100;
      };
      description = ''
        HTTPS handlers on this machine's own tailnet name, keyed by path.
        tailscaled terminates TLS, so a bare port is proxied to as plain HTTP.
      '';
    };

    services = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule serviceOptions);
      description = ''
        Tailscale Services (`svc:<name>`) this host's tailscaled serves. Each
        has to be defined in the tailnet, and the host approved for it, before
        it is reachable.
      '';
    };
  };

  config = lib.mkIf (cfg != { } || nodeCfg.https != { }) {
    assertions = [
      {
        assertion = config.services.tailscale.enable;
        message = "homelab.tailscale.serve: requires services.tailscale.enable";
      }
      {
        assertion = lib.allUnique (map pathUnitName (lib.attrNames nodeCfg.https));
        message = "homelab.tailscale.serve.node.https: paths collide once made into unit names";
      }
    ]
    ++ map (path: {
      assertion = lib.hasPrefix "/" path;
      message = "homelab.tailscale.serve.node.https.\"${path}\": path must start with /";
    }) (lib.attrNames nodeCfg.https)
    ++ lib.flatten (
      lib.mapAttrsToList (name: service: [
        {
          assertion = builtins.match "[a-z0-9]([a-z0-9-]*[a-z0-9])?" name != null;
          message = "homelab.tailscale.serve.services.${name}: name must be a DNS label";
        }
        {
          assertion = serveCommands name service != [ ];
          message = "homelab.tailscale.serve.services.${name}: has no endpoints";
        }
        {
          assertion =
            let
              ports =
                lib.optional (service.https != null) "443"
                ++ lib.attrNames service.tcp
                ++ lib.attrNames service.tlsTcp;
            in
            lib.allUnique ports;
          message = "homelab.tailscale.serve.services.${name}: a port is used by more than one endpoint";
        }
      ]) cfg
    );

    systemd.services =
      lib.mapAttrs' (
        name: service: lib.nameValuePair "tailscale-service-${name}" (mkServiceUnit name service)
      ) cfg
      // lib.mapAttrs' (
        path: to: lib.nameValuePair (pathUnitName path) (mkNodeUnit path to)
      ) nodeCfg.https;
  };
}
