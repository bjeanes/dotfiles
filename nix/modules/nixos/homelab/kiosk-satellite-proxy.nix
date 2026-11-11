# Serves Kiosk Satellite updates to kiosks that can't reach GitHub
{
  config,
  lib,
  ...
}:
let
  svc = "kiosk-satellite-proxy";
  cfg = config.homelab.services.${svc};
  repo = "jxlarrea/kiosk-satellite";
in
{
  options.homelab.services.${svc} = {
    enable = lib.mkEnableOption svc;

    port = lib.mkOption {
      default = 8125;
      type = lib.types.port;
      description = ''
        Port to serve on. Point the kiosk's custom update repository at
        `http://<host>:<port>/kiosk-satellite`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;

      # Needed to proxy_pass to a URL built from variables
      resolver.addresses = [ "127.0.0.53" ];

      proxyCachePath.${svc} = {
        enable = true;
        keysZoneName = "kiosk_satellite";
        inactive = "1d";
      };

      virtualHosts.${svc} = {
        listen = [
          {
            addr = "0.0.0.0";
            port = cfg.port;
          }
          {
            addr = "[::]";
            port = cfg.port;
          }
        ];

        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_ssl_verify on;
          proxy_ssl_verify_depth 3;
          proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;
        '';

        locations = {
          "/".return = "404";

          "= /kiosk-satellite/releases.json" = {
            proxyPass = "https://api.github.com";
            extraConfig = ''
              rewrite ^ /repos/${repo}/releases?per_page=30 break;

              # GitHub's Cache-Control says 60 seconds. However, unauthenticated API
              # calls are limited to 60 an hour, and GitHub answers 403 past that.
              proxy_cache kiosk_satellite;
              proxy_ignore_headers Cache-Control Expires;
              proxy_cache_valid 200 15m;
              proxy_cache_use_stale error timeout updating http_403 http_429 http_500 http_502 http_503 http_504;
            '';
          };

          # Asset names embed the release tag, e.g. kiosk-satellite-2026.11.16.arm64-v8a.apk
          "~ ^/kiosk-satellite/(?<asset>kiosk-satellite-(?<tag>[0-9]+(\\.[0-9]+)*)(\\.[a-z0-9_-]+)?\\.apk)$" =
            {
              proxyPass = "https://github.com/${repo}/releases/download/$tag/$asset";
              extraConfig = ''
                # GitHub's redirect has a signed CDN URL and large security headers
                proxy_buffer_size 32k;
                proxy_buffers 4 32k;

                proxy_intercept_errors on;
                error_page 301 302 307 = @kiosk_satellite_asset;
              '';
            };

          # Follows GitHub's redirect to its CDN, which nginx won't do on its own
          "@kiosk_satellite_asset".extraConfig = ''
            set $location $upstream_http_location;
            proxy_pass $location;
            proxy_buffering off;
          '';
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
