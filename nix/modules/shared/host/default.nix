{
  flake,
  hostName,
  lib,
  ...
}:
{
  networking.hostName = hostName;
  system.configurationRevision = lib.mkIf (flake ? rev) flake.rev;
}
