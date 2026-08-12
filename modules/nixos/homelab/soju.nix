{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  svc = "soju";
  tsnet = "griffin-climb.ts.net";
in
{
  options.homelab.services.${svc} = {
    enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable ${svc}";
    };

    image = lib.mkOption {
      default = "codeberg.org/emersion/${svc}:latest";
      type = lib.types.str;
      description = "OCI image for ${svc}";
    };

    hostName = lib.mkOption {
      default = "irc";
      type = lib.types.str;
      description = "Tailnet hostname to expose ${svc} as";
    };

    gamja = {
      enable = lib.mkOption {
        default = true;
        type = lib.types.bool;
        description = "Serve the gamja web client in front of ${svc}";
      };

      image = lib.mkOption {
        default = "codeberg.org/emersion/gamja:latest";
        type = lib.types.str;
        description = "OCI image for gamja";
      };
    };

    configDir = lib.mkOption {
      default = "/var/lib/homelab/${svc}";
      example = "/var/lib/homelab/${svc}";
      type = lib.types.str;
      description = "Location to store service config";
    };

    timeZone = lib.mkOption {
      default = config.homelab.timeZone;
      type = lib.types.str;
      description = "Time zone for ${svc}";
    };

    backupToNAS = lib.mkOption {
      default = true;
      type = lib.types.bool;
      description = "Back up configDir to legacy location on NAS";
    };
  };

  config =
    let
      myLib = lib.${namespace};
      cfg = config.homelab.services.${svc};
      buildBackupScriptForDir = myLib.buildBackupScriptForDir pkgs svc;
      mkTailscaleQuadletContainer = myLib.mkTailscaleQuadletContainer pkgs config;

      inherit (config.virtualisation.quadlet) pods;

      podName = "${svc}-pod";
      fqdn = "${cfg.hostName}.${tsnet}";

      # Every container in the pod shares one network namespace, so these are
      # a single port space. gamja takes 80 so the Tailscale HTTPS handler can
      # proxy straight to it, which pushes soju's own HTTP listener (WebSocket
      # and file uploads, both reverse-proxied by gamja) off its default of 80.
      ircPort = 6667;
      httpPort = 8090;

      # Standard IRC-over-TLS port, terminated by tailscaled rather than soju.
      tlsIrcPort = 6697;

      sojuConfig = pkgs.writeText "soju-config" ''
        hostname ${fqdn}

        db sqlite3 /db/main.db
        message-store db
        file-upload fs /uploads/

        listen irc+insecure://:${toString ircPort}
        listen http+insecure://:${toString httpPort}
        listen unix+admin://

        # tailscaled terminates TLS for the IRC port and prepends a PROXY v2
        # header so soju sees the real client rather than the forwarder. It
        # shares this pod's netns, so it connects over loopback.
        accept-proxy-ip localhost

        http-ingress https://${fqdn}
      '';

      gamjaConfig = pkgs.writeText "gamja-config.json" (builtins.toJSON { });

      /*
        Replaces the image's own kimchi config, which reverse-proxies soju via
        the `gamja-backend` Compose alias. Only the static routes are kept:
        kimchi's `reverse_proxy` dereferences a nil TLS state on plaintext
        connections and panics, dropping the connection mid-response, and
        tailscaled terminates TLS so every connection it makes is plaintext.
        soju's own endpoints are routed by tailscaled instead — see `https`
        below. Fixed upstream in kimchi 30fd9a9 (2026-04-18), but the published
        gamja image was built two days earlier; this stays correct either way.
      */
      kimchiConfig = pkgs.writeText "kimchi-config" ''
        site http+insecure:// {
          file_server /gamja
        }

        site http+insecure:///config.json {
          file_server /gamja-config.json
        }
      '';
    in
    lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          # soju runs as root inside the container and the image has no
          # PUID/PGID support, so its state stays root-owned on the host.
          systemd.tmpfiles.rules = [
            "d ${cfg.configDir}         0700 root root - -"
            "d ${cfg.configDir}/db      0700 root root - -"
            "d ${cfg.configDir}/uploads 0700 root root - -"
          ];

          virtualisation.quadlet = {
            pods.${podName} = { };
            containers.${svc} = {
              autoStart = true;
              containerConfig = {
                pod = pods.${podName}.ref;
                autoUpdate = "registry";
                image = cfg.image;
                environments = {
                  TZ = cfg.timeZone;
                };
                volumes = [
                  "${sojuConfig}:/soju-config:ro"
                  "${cfg.configDir}/db:/db"
                  "${cfg.configDir}/uploads:/uploads"
                ];
              };
              unitConfig = {
                AssertPathIsDirectory = [
                  "${cfg.configDir}/db"
                  "${cfg.configDir}/uploads"
                ];
              };
            };
          };
        }

        (lib.mkIf cfg.gamja.enable {
          virtualisation.quadlet.containers.gamja = {
            autoStart = true;
            containerConfig = {
              pod = pods.${podName}.ref;
              autoUpdate = "registry";
              image = cfg.gamja.image;
              volumes = [
                "${kimchiConfig}:/kimchi-config:ro"
                "${gamjaConfig}:/gamja-config.json:ro"
              ];
            };
          };
        })

        # NOTE: keep this argument's *shape* independent of `config`. Deriving
        # the attribute names from an option (e.g. via `//` and
        # `optionalAttrs`) forces them while the module system is still working
        # out this module's config, which is an infinite recursion. Conditional
        # *values* are lazy, so they are fine.
        (mkTailscaleQuadletContainer "${svc}-tailscale" {
          inherit podName;
          hostname = cfg.hostName;

          # gamja's static assets come from kimchi on 80; soju's own HTTP
          # endpoints are proxied straight to it, bypassing kimchi's panicking
          # `reverse_proxy`. tailscaled strips the mount point and re-appends
          # the target's path, so these map onto soju 1:1 — including
          # `/uploads/<id>`, since handler lookup walks parent paths.
          https =
            if cfg.gamja.enable then
              {
                "/" = 80;
                "/socket" = "http://localhost:${toString httpPort}/socket";
                "/uploads" = "http://localhost:${toString httpPort}/uploads";
              }
            else
              null;

          tlsTcp = [
            {
              listen = tlsIrcPort;
              target = ircPort;
              proxyProtocol = 2;
            }
          ];
        })

        (lib.mkIf cfg.backupToNAS (buildBackupScriptForDir cfg.configDir { inherit (cfg) timeZone; }))
      ]
    );
}
