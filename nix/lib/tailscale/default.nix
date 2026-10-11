{ lib, ... }: rec {
  # e.g. complicated serve.json:
  # {
  #   "TCP": {
  #     "123": {
  #       "TCPForward": "127.0.0.1:456"
  #     },
  #     "6697": {
  #       "TCPForward": "127.0.0.1:6501",
  #       "TerminateTLS": "${TS_CERT_DOMAIN}"
  #     },
  #     "8080": {
  #       "HTTP": true
  #     },
  #     "8443": {
  #       "HTTPS": true
  #     }
  #   },
  #   "Web": {
  #     "${TS_CERT_DOMAIN}:8080": {
  #       "Handlers": {
  #         "/": {
  #           "Proxy": "http://127.0.0.1:8888"
  #         }
  #       }
  #     },
  #     "${TS_CERT_DOMAIN}:8443": {
  #       "Handlers": {
  #         "/": {
  #           "Proxy": "http://127.0.0.1:9999"
  #         },
  #         "/test": {
  #           "Proxy": "https://localhost:9999/hello"
  #         }
  #       }
  #     }
  #   },
  #   "AllowFunnel": {
  #     "${TS_CERT_DOMAIN}:123": true
  #   }
  # }
  mkTailscaleServeConfig =
    pkgs:
    {
      tcp ? null,
      tlsTcp ? null,
      https ? null,
      funnel ? null,
    }:
    let
      inherit (lib)
        concatMapStringsSep
        listToAttrs
        mapAttrs
        nameValuePair
        optionalAttrs
        ;

      tcp' = if tcp == null then [ ] else tcp;
      tlsTcp' = if tlsTcp == null then [ ] else tlsTcp;
      https' = if https == null then { } else https;
      funnel' = if funnel == null then [ ] else funnel;

      certDomain = "\${TS_CERT_DOMAIN}";

      fail = message: throw "mkTailscaleServeConfig: ${message}";

      parsePort =
        value:
        let
          string = toString value;
          matched = builtins.match "([0-9]+)" string;

          port =
            if matched == null then fail "invalid port `${string}`" else lib.toInt (builtins.head matched);
        in
        if port < 1 || port > 65535 then fail "port `${string}` is outside 1–65535" else port;

      /*
        Accepted forms:

          22
            Listen on 22 and forward to localhost:22.

          "22:2222"
            Listen on 22 and forward to localhost:2222.

          "22:forgejo:2222"
            Listen on 22 and forward to forgejo:2222.

          { listen = 6697; target = 6667; proxyProtocol = 2; }
            As above, but with per-port options. `target` defaults to `listen`
            and takes either a port or `host:port`. `proxyProtocol` prepends a
            PROXY protocol header (1 or 2) so the backend can recover the
            original client address, which TLS termination would otherwise
            hide; the backend must be configured to expect it.

        The same forms are used by both `tcp` (raw forwarding) and `tlsTcp`
        (tailscaled terminates TLS, then forwards plaintext to the target).
      */
      parseTcp =
        specification:
        let
          string = toString specification;

          samePort = builtins.match "([0-9]+)" string;
          localPort = builtins.match "([0-9]+):([0-9]+)" string;
          hostPort = builtins.match "([0-9]+):([^:]+):([0-9]+)" string;

          parsed =
            if builtins.isInt specification then
              {
                listen = parsePort specification;
                target = "localhost:${toString specification}";
              }
            else if samePort != null then
              let
                port = builtins.elemAt samePort 0;
              in
              {
                listen = parsePort port;
                target = "localhost:${port}";
              }
            else if localPort != null then
              {
                listen = parsePort (builtins.elemAt localPort 0);
                target = "localhost:${builtins.elemAt localPort 1}";
              }
            else if hostPort != null then
              {
                listen = parsePort (builtins.elemAt hostPort 0);
                target = "${builtins.elemAt hostPort 1}:" + builtins.elemAt hostPort 2;
              }
            else
              fail "invalid TCP forwarding specification `${string}`";
        in
        if builtins.isAttrs specification then
          parseTcpOptions specification
        else
          parsed // { proxyProtocol = null; };

      normaliseTarget =
        target:
        if builtins.isInt target then
          "localhost:${toString (parsePort target)}"
        else if builtins.isString target then
          (
            if builtins.match "([0-9]+)" target == null then
              target
            else
              "localhost:${toString (parsePort target)}"
          )
        else
          fail "TCP target must be an integer port or string";

      parseTcpOptions =
        options:
        let
          unknown = builtins.attrNames (
            removeAttrs options [
              "listen"
              "target"
              "proxyProtocol"
            ]
          );

          proxyProtocol = options.proxyProtocol or null;
        in
        if unknown != [ ] then
          fail "unknown TCP option(s) ${concatMapStringsSep ", " (name: "`${name}`") unknown}"
        else if !(options ? listen) then
          fail "TCP entry is missing `listen`"
        else if
          proxyProtocol != null
          && !(builtins.elem proxyProtocol [
            1
            2
          ])
        then
          fail "`proxyProtocol` must be 1 or 2, got `${toString proxyProtocol}`"
        else
          {
            listen = parsePort options.listen;
            target = normaliseTarget (options.target or options.listen);
            inherit proxyProtocol;
          };

      /*
        `TerminateTLS` is the SNI name tailscaled will serve — and the only one
        it accepts — so it must be the node's own cert domain. containerboot
        substitutes `${TS_CERT_DOMAIN}` throughout serve.json, not just in the
        `Web` keys, so the placeholder works here too.
      */
      mkTcpEntry =
        { terminateTLS }:
        specification:
        let
          parsed = parseTcp specification;
        in
        parsed
        // {
          entry = nameValuePair (toString parsed.listen) (
            {
              TCPForward = parsed.target;
            }
            // optionalAttrs terminateTLS {
              TerminateTLS = certDomain;
            }
            // optionalAttrs (parsed.proxyProtocol != null) {
              ProxyProtocol = parsed.proxyProtocol;
            }
          );
        };

      normaliseUpstream =
        upstream:
        if builtins.isInt upstream then
          "http://localhost:${toString (parsePort upstream)}"
        else if builtins.isString upstream then
          upstream
        else
          fail "HTTPS upstream must be an integer port or string";

      /*
        Both forms are accepted:

          https = 3000;

          https = {
            "/" = 3000;
            "/api" = "http://api:8080";
          };
      */
      httpsHandlers =
        if builtins.isInt https' || builtins.isString https' then
          {
            "/" = {
              Proxy = normaliseUpstream https';
            };
          }
        else if builtins.isAttrs https' then
          mapAttrs (_path: upstream: {
            Proxy = normaliseUpstream upstream;
          }) https'
        else
          fail "`https` must be null, an upstream, or an attrset of path prefixes";

      hasTcp = tcp' != [ ] || tlsTcp' != [ ];
      hasHttps = httpsHandlers != { };
      hasFunnel = funnel' != [ ];
      isEmpty = !(hasTcp || hasHttps || hasFunnel);

      parsedTcp =
        map (mkTcpEntry { terminateTLS = false; }) tcp'
        ++ map (mkTcpEntry { terminateTLS = true; }) tlsTcp';

      tcpPorts = map (entry: toString entry.listen) parsedTcp;

      duplicateTcpPorts = lib.filter (port: lib.count (candidate: candidate == port) tcpPorts > 1) (
        lib.unique tcpPorts
      );

      funnelPorts = map parsePort funnel';

      config =
        assert lib.assertMsg (duplicateTcpPorts == [ ])
          "mkTailscaleServeConfig: duplicate TCP listen ports: ${
            concatMapStringsSep ", " toString duplicateTcpPorts
          }";

        assert lib.assertMsg (
          !hasHttps || !(builtins.elem "443" tcpPorts)
        ) "mkTailscaleServeConfig: port 443 cannot be both HTTPS and TCP-forwarded";

        {
          TCP =
            listToAttrs (map (parsed: parsed.entry) parsedTcp)
            // optionalAttrs hasHttps {
              "443".HTTPS = true;
            };
        }
        // optionalAttrs hasHttps {
          Web."${certDomain}:443".Handlers = httpsHandlers;
        }
        // optionalAttrs hasFunnel {
          AllowFunnel = listToAttrs (
            map (port: nameValuePair "${certDomain}:${toString port}" true) funnelPorts
          );
        };
      json = pkgs.formats.json { };

      directory = pkgs.runCommand "tailscale-serve-config" { } ''
        mkdir -p "$out"
        cp ${json.generate "serve.json" config} "$out/serve.json"
      '';
    in
    if isEmpty then null else "${directory}/serve.json";

  mkTailscaleContainerCommon =
    pkgs: config: name:
    {
      hostname ? name,
      authKeyFile ? config.age.secrets.tailscale-auth-service.path,
      storePath ? "/var/lib/tailscale/ctr-${name}",
      # NOTE: ignored if ephemeral
      image ? "docker.io/tailscale/tailscale:latest",
      ephemeral ? false,
      https ? null,
      tcp ? null,
      tlsTcp ? null,
      funnel ? null,
      tags ? [
        "tag:home"
        "tag:service"
      ],
      user ? null,
      group ? null,
      # Taildrive shares as { <share-name> = <host path>; }
      drive ? { },
    }@opts:
    with lib;
    let
      serveJson = mkTailscaleServeConfig pkgs {
        inherit
          https
          tcp
          tlsTcp
          funnel
          ;
      };
      hasServeConfig = serveJson != null;

      ownerGroup = if group == null then user else group;

      # Share name -> path the host directory is mounted at in the container
      driveShares = mapAttrs (shareName: _: "/taildrive/${shareName}") drive;
    in
    {
      inherit image hostname user;
      environment = {
        TS_EXTRA_ARGS = "--advertise-tags=${concatStringsSep "," tags}";
        TS_HOSTNAME = hostname;
        TS_ACCEPT_DNS = "true";
        TS_AUTH_ONCE = "true";
      }
      // optionalAttrs ephemeral {
        TS_TAILSCALED_EXTRA_ARGS = "--state=mem:";
      }
      // optionalAttrs (!ephemeral) {
        TS_STATE_DIR = "/var/lib/tailscale";
      }
      // optionalAttrs hasServeConfig {
        TS_SERVE_CONFIG = "/config/serve.json";
      };

      dynamicEnvironment = {
        TS_AUTHKEY = "cat ${escapeShellArg authKeyFile} | tr -d '\n' && echo -n '?ephemeral=${
          if ephemeral then "true" else "false"
        }'";
      };

      inherit driveShares;

      /*
        `--hostuser` copies the host's passwd entry into the container's
        generated /etc/passwd before podman resolves `--user`, so the name is
        enough and the uid stays as stateful as it actually is. The entry is
        also what lets tailscaled name the share's owner.
      */
      extraOptions = optionals (user != null) [
        "--hostuser=${user}"
        "--user=${user}"
      ];

      volumes =
        (optionals (!ephemeral) [ "${storePath}:/var/lib/tailscale" ])
        ++ (optionals hasServeConfig [ "${builtins.dirOf serveJson}:/config:ro" ])
        ++ (mapAttrsToList (shareName: hostPath: "${hostPath}:${driveShares.${shareName}}") drive);

      config.assertions = [
        {
          assertion = drive == { } || user != null;
          message = "mkTailscaleContainer: `drive` requires `user`; tailscaled refuses to serve Taildrive shares as root";
        }
      ];

      config.systemd.tmpfiles.rules = optionals (!ephemeral) (
        if user == null then
          [ "d ${storePath} 0775 root root - -" ]
        else
          [
            "d ${storePath} 0750 ${user} ${ownerGroup} - -"
            # Existing state predates the switch away from root
            "Z ${storePath} - ${user} ${ownerGroup} - -"
          ]
      );
    };

  /*
    Publish Taildrive shares for a tailscale sidecar once tailscaled is up.

    containerboot has no Taildrive support, so the shares have to be set over
    the local API after the daemon authenticates; they then persist in the
    node's prefs. Sharing also needs the `drive:share` node attribute in the
    tailnet policy file, and the local API rejects it until then, which is why
    this retries rather than failing on the first attempt.
  */
  mkTaildriveShares =
    pkgs:
    {
      containerName,
      unit,
      shares,
      # Quadlet is podman-only; oci-containers passes its configured backend
      ctr ? "${pkgs.podman}/bin/podman",
    }:
    let

      script = pkgs.writeShellScript "${containerName}-taildrive-shares" /* bash */ ''
        set -euo pipefail

        # containerboot puts the socket at TS_SOCKET (/tmp/tailscaled.sock by
        # default) and only symlinks it to the well-known path when it can
        # write /var/run/tailscale, which it cannot as a non-root container.
        ts() {
          ${ctr} exec ${lib.escapeShellArg containerName} \
            tailscale --socket=/tmp/tailscaled.sock "$@"
        }

        # The share is served as whoever creates it, which is the container's
        # user, because `exec` inherits it.
        share() {
          for _ in $(${pkgs.coreutils}/bin/seq 60); do
            if ts drive share "$1" "$2"; then
              return 0
            fi
            ${pkgs.coreutils}/bin/sleep 2
          done

          echo "timed out publishing Taildrive share $1" >&2
          return 1
        }

        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            shareName: mountPath: "share ${lib.escapeShellArg shareName} ${lib.escapeShellArg mountPath}"
          ) shares
        )}
      '';
    in
    lib.mkIf (shares != { }) {
      systemd.services."${containerName}-taildrive" = {
        description = "Publish Taildrive shares for ${containerName}";
        after = [ unit ];
        requires = [ unit ];
        # Stop with the container, and start again when it does
        partOf = [ unit ];
        wantedBy = [ unit ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = script;
        };
      };
    };
}
