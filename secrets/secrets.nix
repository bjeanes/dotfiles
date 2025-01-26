let
  borogrove = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDwjs401oUl5CYv0bijTQyHQgRFJuCGbcpgUzrYSlMak";
  brillig = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPGIUDOsRo5QmbXpUNqan5WjasENTVtrfEe3XQFxkaZJ";
  tumtum = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA9/LnXIRJW8TfdfNnCBuo5HfU+fIUxLHMex9dBycClU";
  bjeanes = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJykg+5TulcwmeKFYSjZmnrL5/Fo4kWmOV1fAyt41Evh";

  users = [ bjeanes ];
  systems = [
    tumtum
    borogrove
    brillig
  ];

  all = systems ++ users;
in
{
  "default-password.age".publicKeys = all;

  # non-ephemeral tailscale services tagged with tag:home,tag:server
  "tailscale-auth-server.age".publicKeys = all;

  # ephemeral tailscale services tagged with tag:home,tag:service
  "tailscale-auth-service.age".publicKeys = all;

  "sonarr-api-key.age".publicKeys = all;
  "radarr-api-key.age".publicKeys = all;
  "lidarr-api-key.age".publicKeys = all;
  "prowlarr-api-key.age".publicKeys = all;
  "homeassistant-api-key.age".publicKeys = all;
  "plex-token.age".publicKeys = all;
  "tautulli-api-key.age".publicKeys = all;

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
