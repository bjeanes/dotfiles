{ lib, ... }: {
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
        parsed;

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
}
