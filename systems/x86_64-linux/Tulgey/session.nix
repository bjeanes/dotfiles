# Kiosk (sway + Chromium) or an interactive GNOME desktop, per `panel.interactive`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.panel;

  swayConfig = pkgs.writeText "tulgey-kiosk.conf" ''
    output eDP-1 scale 2

    default_border none
    default_floating_border none
    xwayland disable

    # squeekboard only self-selects dark under Phosh; GTK_THEME picks the
    # dark stylesheet it already ships. Read once at startup.
    exec env GTK_THEME=Adwaita:dark ${lib.getExe pkgs.squeekboard}

    # --disable-pinch locks out pinch-to-zoom of the page viewport, which on a
    # wall panel is only ever triggered by accident
    #
    # --enable-wayland-ime plus --wayland-text-input-version=3 are what allows 
    # on-screen keyboard to hook into appropriate events to show itself.
    #
    # Not using --kiosk so that Sway can tile the keyboard under Chromium,
    # instead of covering content you may need to interact with (e.g. to focus
    # on a different input element)
    exec ${lib.getExe pkgs.chromium} \
      --app=${cfg.dashboardUrl} \
      --ozone-platform=wayland \
      --enable-wayland-ime \
      --wayland-text-input-version=3 \
      --noerrdialogs \
      --disable-infobars \
      --disable-pinch \
      --disable-features=TranslateUI,OverscrollHistoryNavigation
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

    # squeekboard gates auto-show on this key; nothing outside Phosh sets it.
    programs.dconf = {
      enable = true;
      profiles.user.databases = [
        {
          settings."org/gnome/desktop/a11y/applications".screen-keyboard-enabled = true;
        }
      ];
    };
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
