{ ... }: {
  config = {
    environment.shellAliases =
      {
        # https://github.com/tailscale/tailscale/issues/3805#issuecomment-1707050952
        tailscale = "/Applications/Tailscale.app/Contents/MacOS/Tailscale";
      };
  };
}
