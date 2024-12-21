{
  hosts = {
    nas = rec {
      zt = "10.144.70.159"; # ZeroTier
      ts = "100.120.117.10"; # Tailscale
      lan = "10.10.10.10"; # local
      addresses = [ zt ts lan ];
    };

    tumtum = rec {
      zt = "10.144.119.0"; # ZeroTier
      ts = "100.87.76.44"; # Tailscale
      lan = "10.10.10.46"; # local
      addresses = [ zt ts lan ];
    };

    borogrove = rec {
      zt = "10.144.230.45"; # ZeroTier
      ts = "100.125.176.115"; # Tailscale
      addresses = [ zt ts ];
    };

    homeassistant = rec {
      aliases = [ "hass" "home-assistant" ];
      zt = "10.144.245.56"; # ZeroTier
      ts = "100.80.108.14"; # Tailscale
      lan = "10.10.10.73"; # local
      addresses = [ zt ts lan ];
    };

    bandersnatch = rec {
      zt = "10.144.79.92"; # ZeroTier
      ts = "100.101.219.23"; # Tailscale
      addresses = [ zt ts ];
    };

    jabberwocky = rec {
      zt = "10.144.6.239"; # ZeroTier
      ts = "100.126.78.67"; # Tailscale
      addresses = [ zt ts ];
    };
  };
}
