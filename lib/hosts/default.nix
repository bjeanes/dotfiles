{
  hosts = {
    nas.addresses = [
      "10.144.70.159" # ZeroTier
      "100.120.117.10" # Tailscale
      "10.10.10.10" # local
    ];

    tumtum.addresses = [
      "10.144.119.0" # ZeroTier
      "100.87.76.44" # Tailscale
      "10.10.10.46" # local
    ];

    borogrove.addresses = [
      "10.144.230.45" # ZeroTier
      "100.125.176.115" # Tailscale
    ];

    homeassistant = {
      aliases = [ "hass" "home-assistant" ];
      addresses = [
        "10.144.245.56" # ZeroTier
        "100.80.108.14" # Tailscale
        "10.10.10.73" # local
      ];
    };

    bandersnatch.addresses = [
      "10.144.79.92" # ZeroTier
      "100.101.219.23" # Tailscale
    ];

    jabberwocky.addresses = [
      "10.144.6.239" # ZeroTier
      "100.126.78.67" # Tailscale
    ];
  };
}
