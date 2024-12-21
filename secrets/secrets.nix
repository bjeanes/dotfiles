let
  borogrove = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDwjs401oUl5CYv0bijTQyHQgRFJuCGbcpgUzrYSlMak";
  bjeanes = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJykg+5TulcwmeKFYSjZmnrL5/Fo4kWmOV1fAyt41Evh";

  systems = [ borogrove ];
in
{
  "tailscale-auth.age".publicKeys = systems ++ [ bjeanes ];
}
