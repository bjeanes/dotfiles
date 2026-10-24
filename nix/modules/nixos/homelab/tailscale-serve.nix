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
  registerCfg = config.homelab.tailscale.serve.register;
  tailscale = lib.getExe config.services.tailscale.package;
  inherit (config.homelab.tailscale) tailnet;

  /*
    Defines a Service in the tailnet before it is advertised, so neither that
    nor freeing its name is a trip to the admin console. A machine still
    holding the name is deleted only if it carries `replaceTag` (i.e. it is an
    old sidecar) and is offline; otherwise this fails, and the unit retries
    until the sidecar has gone. An existing Service is updated in place, keeping
    its addresses, only when its ports or tags differ.
  */
  register = pkgs.writeShellApplication {
    name = "tailscale-service-register";
    runtimeInputs = with pkgs; [
      curl
      jq
    ];
    text = ''
      spec="$1"
      name="$(jq -r .name "$spec")"
      fqdn="$(jq -r .fqdn "$spec")"
      replaceTag="$(jq -r '.replaceTag // empty' "$spec")"
      base=https://api.tailscale.com/api/v2

      body="$(mktemp)"
      trap 'rm -f "$body"' EXIT

      # Secrets go through process substitution to stay out of argv
      token="$(
        curl -fsS "$base/oauth/token" \
          --data-urlencode "client_id=$TS_API_CLIENT_ID" \
          --data-urlencode client_secret@<(printf %s "$TS_API_CLIENT_SECRET") |
          jq -r .access_token
      )"

      # Prints the HTTP status; the response is left in $body
      api() {
        curl -sS -o "$body" -w '%{http_code}' \
          -H @<(printf 'Authorization: Bearer %s\n' "$token") "$@"
      }

      fail() {
        echo "$1 (HTTP $2):" >&2
        cat "$body" >&2
        exit 1
      }

      status="$(api --get "$base/tailnet/-/devices" --data-urlencode "name=$fqdn" --data-urlencode fields=all)"
      [[ $status == 200 ]] || fail "listing devices" "$status"

      # Filtered again here in case the API ever ignores the query
      devices="$(jq -c --arg fqdn "$fqdn" '.devices[] | select(.name == $fqdn)' "$body")"
      while IFS= read -r device; do
        [[ -n $device ]] || continue
        id="$(jq -r .nodeId <<<"$device")"

        if [[ -z $replaceTag ]] || ! jq -e --arg tag "$replaceTag" '.tags // [] | index($tag)' <<<"$device" >/dev/null; then
          echo "$fqdn belongs to machine $id, which isn't tagged ''${replaceTag:-for replacement}; delete it by hand" >&2
          exit 1
        fi

        if jq -e .connectedToControl <<<"$device" >/dev/null; then
          echo "$fqdn belongs to machine $id, which is still connected; waiting for it to go" >&2
          exit 1
        fi

        echo "deleting machine $id, which held $fqdn"
        status="$(api -X DELETE "$base/device/$id")"
        [[ $status == 200 ]] || fail "deleting machine $id" "$status"
      done <<<"$devices"

      put() {
        status="$(api -X PUT -H 'Content-Type: application/json' --data-binary @- "$base/tailnet/-/services/$name")"
        [[ $status == 200 ]] || fail "defining $name" "$status"
      }

      status="$(api "$base/tailnet/-/services/$name")"
      case $status in
        404)
          echo "defining $name"
          jq '{name, ports, tags, comment}' "$spec" | put
          ;;
        200)
          if jq -e --slurpfile want "$spec" \
            '(.ports | sort) == ($want[0].ports | sort) and (.tags // [] | sort) == ($want[0].tags | sort)' \
            "$body" >/dev/null; then
            echo "$name is already defined as configured"
          else
            echo "updating $name"
            jq --slurpfile want "$spec" '.ports = $want[0].ports | .tags = $want[0].tags' "$body" | put
          fi
          ;;
        *)
          fail "looking up $name" "$status"
          ;;
      esac
    '';
  };

  registerSpec =
    name: service:
    pkgs.writeText "tailscale-service-${name}.json" (
      builtins.toJSON {
        name = "svc:${name}";
        fqdn = "${name}.${tailnet}";
        ports = map (port: "tcp:${port}") (
          lib.optional (service.https != null) "443"
          ++ lib.attrNames service.tcp
          ++ lib.attrNames service.tlsTcp
        );
        inherit (registerCfg) tags;
        replaceTag = registerCfg.replaceMachinesTagged;
        comment = "Managed by NixOS on ${config.networking.hostName}";
      }
    );

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
      "network-online.target"
      "tailscaled.service"
      "tailscaled-autoconnect.service"
    ];
    wants = [
      "network-online.target"
      "tailscaled.service"
    ];
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
    mkOneshot "Tailscale Service svc:${name}" (
      {
        ExecStart = pkgs.writeShellScript "tailscale-service-${name}" ''
          set -euo pipefail
          ${clear}
          ${lib.concatStringsSep "\n" (serveCommands name service)}
        '';
        ExecStop = clear;
      }
      // lib.optionalAttrs (registerCfg.credentialsFile != null) {
        ExecStartPre = "${lib.getExe register} ${registerSpec name service}";
        EnvironmentFile = registerCfg.credentialsFile;
      }
    );

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
        it is reachable; see `register` for the former.
      '';
    };

    register = {
      credentialsFile = lib.mkOption {
        default = config.age.secrets.tailscale-oauth-services.path or null;
        defaultText = lib.literalExpression "config.age.secrets.tailscale-oauth-services.path";
        type = lib.types.nullOr lib.types.path;
        description = ''
          Environment file with `TS_API_CLIENT_ID` and `TS_API_CLIENT_SECRET` for
          an OAuth client with the `services` and `devices:core` scopes, used to
          define each Service in the tailnet. `null` leaves that to the admin
          console.
        '';
      };

      tags = lib.mkOption {
        default = [ "tag:homelab-svc" ];
        type = lib.types.listOf lib.types.str;
        description = "Tags Services are defined with, which their auto-approval keys off";
      };

      replaceMachinesTagged = lib.mkOption {
        default = "tag:service";
        type = lib.types.nullOr lib.types.str;
        description = ''
          A machine holding a Service's name is deleted, once offline, only if
          it has this tag, which the old sidecars do. `null` never deletes.
        '';
      };
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
      (
        let
          # Bare ports are what services publish on 127.0.0.1
          localPorts = lib.concatMap (
            service:
            lib.filter builtins.isInt (
              [ service.https ] ++ lib.attrValues service.tcp ++ lib.attrValues service.tlsTcp
            )
          ) (lib.attrValues cfg);
          duplicates = lib.unique (lib.filter (p: lib.count (q: q == p) localPorts > 1) localPorts);
        in
        {
          assertion = duplicates == [ ];
          message = "homelab.tailscale.serve.services: local port(s) ${
            lib.concatMapStringsSep ", " toString duplicates
          } used by more than one service; set `tailscale.localPort` on one of them";
        }
      )
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
