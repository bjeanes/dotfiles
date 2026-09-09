# Kiosk (sway + Chromium) or an interactive GNOME desktop, per `panel.interactive`.
{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:
let
  cfg = config.panel;
  mqttHost = lib.${namespace}.hosts.homeassistant.lan;

  swayConfig = pkgs.writeText "tulgey-kiosk.conf" ''
    output eDP-1 scale 2

    default_border none
    default_floating_border none
    xwayland disable

    # squeekboard only self-selects dark under Phosh; GTK_THEME picks the
    # dark stylesheet it already ships. Read once at startup.
    exec env GTK_THEME=Adwaita:dark ${lib.getExe pkgs.squeekboard}

    exec ${lib.getExe pkgs.${namespace}.touchkio} \
      --web-url=${cfg.dashboardUrl} \
      --mqtt-url=mqtt://${mqttHost}:1883 \
      --mqtt-user=tablet \
      --mqtt-password-file=${config.age.secrets."touchkio-mqtt-password".path} \
      --web-zoom=1
  '';

  kioskSession = {
    command = "${lib.getExe pkgs.sway} --config ${swayConfig}";
    user = "tablet";
  };
in
{
  options.panel = {
    dashboardUrl = lib.mkOption {
      type = lib.types.str;
      description = "URL the kiosk session opens on.";
    };

    interactive = lib.mkEnableOption ''
      a full GNOME desktop instead of the single-application kiosk session
    '';
  };

  config = {
    users.users.tablet = {
      isNormalUser = true;
      description = "Wall panel session";
      group = "users";
      extraGroups = [
        "video"
        "input"
      ];
      hashedPassword = "";
    };

    # The empty password above is console-only.
    services.openssh.settings.DenyUsers = [ "tablet" ];

    services.greetd = lib.mkIf (!cfg.interactive) {
      enable = true;
      settings = {
        initial_session = kioskSession;
        # Mandatory even with an autologin; same session so a dead kiosk
        # returns instead of a bare VT.
        default_session = kioskSession;
      };
    };

    # Read in-process by touchkio, so it never reaches argv or a disk copy.
    age.secrets."touchkio-mqtt-password".owner = "tablet";

    systemd.services.greetd.restartIfChanged = lib.mkIf (!cfg.interactive) (lib.mkForce true);

    # squeekboard gates auto-show on this key; nothing outside Phosh sets it.
    programs.dconf = {
      enable = true;
      profiles.user.databases = [
        {
          settings."org/gnome/desktop/a11y/applications".screen-keyboard-enabled = true;
        }
      ];
    };

    # For the interactive session; the kiosk itself is touchkio.
    environment.systemPackages = [ pkgs.${namespace}.touchkio ];

    services.desktopManager.gnome.enable = cfg.interactive;
    services.displayManager = lib.mkIf cfg.interactive {
      gdm.enable = true;
      autoLogin = {
        enable = true;
        user = "tablet";
      };
    };
  };
}
