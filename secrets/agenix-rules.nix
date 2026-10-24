let
  inherit (import ../nix/lib/hosts) hosts;

  borogrove = hosts.borogrove.hostKey;
  brillig = hosts.brillig.hostKey;
  tumtum = hosts.tumtum.hostKey;
  tulgey = hosts.tulgey.hostKey;

  bandersnatch = hosts.bandersnatch.ageHostKey;
  jabberwocky = hosts.jabberwocky.ageHostKey;

  bjeanes = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJykg+5TulcwmeKFYSjZmnrL5/Fo4kWmOV1fAyt41Evh";

  users = [ bjeanes ];
  systems = [
    tumtum
    borogrove
    brillig
    tulgey
  ];

  all = systems ++ users;
in
{
  "default-password.age".publicKeys = all;

  # non-ephemeral tailscale services tagged with tag:home,tag:server
  "tailscale-auth-server.age".publicKeys = all;

  # ephemeral tailscale services tagged with tag:home,tag:service
  "tailscale-auth-service.age".publicKeys = all;

  # OAuth client (services, devices:core) that defines Tailscale Services, as
  # TS_API_CLIENT_ID= and TS_API_CLIENT_SECRET= lines
  "tailscale-oauth-services.age".publicKeys = all;

  "sonarr-api-key.age".publicKeys = all;
  "radarr-api-key.age".publicKeys = all;
  "radarr4k-api-key.age".publicKeys = all;

  "lidarr-api-key.age".publicKeys = all;
  "prowlarr-api-key.age".publicKeys = all;
  "homeassistant-api-key.age".publicKeys = all;
  "plex-token.age".publicKeys = all;
  "tautulli-api-key.age".publicKeys = all;

  # Homepage dashboard widgets
  "bazarr-api-key.age".publicKeys = all;
  "sabnzbd-api-key.age".publicKeys = all;
  "overseerr-api-key.age".publicKeys = all;
  "autobrr-api-key.age".publicKeys = all;
  "qui-api-key.age".publicKeys = all;
  "tracearr-api-key.age".publicKeys = all;
  "plex-dashboard-token.age".publicKeys = all;
  "bookorbit-dashboard-username.age".publicKeys = all;
  "bookorbit-dashboard-password.age".publicKeys = all;
  "unifi-api-key.age".publicKeys = all;
  "nextdns-api-key.age".publicKeys = all;
  "nextdns-profile.age".publicKeys = all;

  "tracearr-jwt-secret.age".publicKeys = all;
  "tracearr-cookie-secret.age".publicKeys = all;

  "yuvomi-session-secret.age".publicKeys = all;
  "yuvomi-db-encryption-key.age".publicKeys = all;

  "bookorbit-jwt-secret.age".publicKeys = all;
  "bookorbit-podcast-encryption-key.age".publicKeys = all;
  "bookorbit-setup-bootstrap-token.age".publicKeys = all;
  "bookorbit-book-request-encryption-key.age".publicKeys = all;

  "touchkio-mqtt-password.age".publicKeys = [
    bjeanes
    tulgey
  ];

  "claude-code-oauth-token.age".publicKeys = [
    bjeanes
    bandersnatch
    jabberwocky
  ];

  "wg-private-key.age".publicKeys = [
    bjeanes
    borogrove
  ];
  "wg-preshared-key.age".publicKeys = [
    bjeanes
    borogrove
  ];
  "wg-addresses.age".publicKeys = [
    bjeanes
    borogrove
  ];
}
