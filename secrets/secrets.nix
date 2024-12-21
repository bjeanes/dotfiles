let
  borogrove = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDwjs401oUl5CYv0bijTQyHQgRFJuCGbcpgUzrYSlMak";
  brillig = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII2b879SKcdqQ5Jb8R/PdNAhJTYY4zxHTRmAX2Y9Nv/b";
  bjeanes = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJykg+5TulcwmeKFYSjZmnrL5/Fo4kWmOV1fAyt41Evh";

  users = [ bjeanes ];
  systems = [ borogrove brillig ];

  all = systems ++ users;
in
{
  "default-password.age".publicKeys = all;
  "tailscale-auth.age".publicKeys = all;
}
