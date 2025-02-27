{
  lanSubnet = "10.10.10.0/24";
  hosts = {
    nas = rec {
      zt = "10.144.70.159";
      ts = "100.120.117.10";
      lan = "10.10.10.10";
      addresses = [
        ts
        zt
        lan
      ];
    };

    tumtum = rec {
      zt = "10.144.119.0";
      ts = "100.87.76.44";
      lan = "10.10.10.46";
      addresses = [
        ts
        zt
        lan
      ];
    };

    borogrove = rec {
      zt = "10.144.230.45";
      ts = "100.125.176.115";
      lan = "10.10.10.104";
      addresses = [
        ts
        zt
      ];
    };

    brillig = rec {
      zt = "10.144.152.237";
      ts = "100.86.7.22";
      lan = "10.10.10.246";
      addresses = [
        ts
        zt
      ];
    };

    homeassistant = rec {
      aliases = [
        "hass"
        "home-assistant"
      ];
      zt = "10.144.245.56";
      ts = "100.80.108.14";
      lan = "10.10.10.73";
      addresses = [
        ts
        zt
        lan
      ];
    };

    bandersnatch = rec {
      zt = "10.144.79.92";
      ts = "100.101.219.23";
      addresses = [
        ts
        zt
      ];
    };

    jabberwocky = rec {
      zt = "10.144.6.239";
      ts = "100.126.78.67";
      addresses = [
        ts
        zt
      ];
    };
  };
}
