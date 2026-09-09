# What the panel actually shows, and who it runs as.
#
# Two mutually exclusive sessions, selected by `panel.interactive`:
#
#   false -> greetd autologins `tablet` into sway, which runs one full-screen
#            Chromium on the dashboard. No display manager, no lock screen.
#   true  -> GDM + GNOME, still autologin as `tablet`. Useful while working on
#            the hardware by hand; GNOME has the most consistent touch handling
#            and picks sane HiDPI scaling on its own.
#
# sway rather than cage for the kiosk: the 3000x2000 panel needs 200% scaling
# and that has to come from the compositor. cage has no output-scale option at
# all, and Chromium's --force-device-scale-factor against an unscaled
# compositor renders into the top-left quarter of the screen with touch dead.
# See nocturne.md.
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

    # On-screen keyboard: squeekboard, the Phosh/Mobian OSK. It shows and
    # hides itself on text-input focus, which is the only workable mode on a
    # wall panel with no physical keyboard and no room for a toggle, and it
    # sizes itself to the output so there is no height to get wrong.
    #
    # This replaces wvkbd. wvkbd's focus-based mode (--auto, new in v0.20 and
    # described by its own changelog as opt-in and "not the default yet")
    # produced three separate failures here: several undismissable keyboards
    # stacking up on focus changes, the process wedging, and every keypress
    # behaving as though held down. Note touchkio drives squeekboard over
    # D-Bus at /sm/puri/OSK0 for the same job, so this is the well-trodden
    # path for a Home Assistant panel.
    exec ${lib.getExe pkgs.squeekboard}

    # --disable-pinch locks out pinch-to-zoom of the page viewport, which on a
    # wall panel is only ever triggered by accident; HA's own map/plot cards
    # keep working because they handle raw touch events themselves rather than
    # relying on browser zoom. With no keyboard there is no ctrl+/- either, so
    # that pins the kiosk at 100%. OverscrollHistoryNavigation goes for the
    # same reason: a stray two-finger swipe should not navigate the SPA back.
    #
    # --enable-wayland-ime plus --wayland-text-input-version=3 are what make
    # Chromium create a text-input object at all; without them wvkbd --auto
    # never receives a focus event and stays hidden. sway speaks only v3,
    # while Chromium still defaults to v1, hence the explicit version.
    # Deliberately NOT --kiosk. --kiosk fullscreens the window, and a
    # fullscreen surface covers the whole output regardless of any layer
    # surface's exclusive zone -- which is why the keyboard used to sit on
    # top of the page instead of shrinking it. Tiled, sway subtracts the
    # keyboard's exclusive zone from the usable area and Chromium reflows
    # above it. --app= already removes the omnibox and all browser chrome.
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
    # Unprivileged (deliberately not in wheel) and passwordless, so both the
    # kiosk session and GDM autologin come up unattended.
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

    # That empty password is only ever usable at the physical console: sshd has
    # password auth off repo-wide, and this shuts the door explicitly.
    services.openssh.settings.DenyUsers = [ "tablet" ];

    # initial_session is the autologin -- no prompt, straight in at boot.
    # default_session is what greetd runs every *other* time, i.e. if the
    # session ever exits; it is mandatory (greetd refuses to start with
    # "default_session contains no command"), and the NixOS module only
    # defaults its `user`, to "greeter". Pointing it at the same session means
    # a crashed or quit kiosk comes straight back rather than leaving the wall
    # showing a bare VT.
    services.greetd = lib.mkIf (!cfg.interactive) {
      enable = true;
      settings = {
        initial_session = kioskSession;
        default_session = kioskSession;
      };
    };

    # squeekboard binds its auto-show to this key, GET-only:
    #
    #   g_settings_bind (settings, "screen-keyboard-enabled", holder,
    #                    "enabled", G_SETTINGS_BIND_GET);
    #
    # Nothing sets it outside Phosh, so it reads false and the keyboard will
    # only appear when told to over D-Bus -- hide-on-blur still works, which
    # makes the failure look like a focus bug rather than a disabled feature.
    # (Had the schema been absent entirely squeekboard would have defaulted to
    # enabled; it is present via its own wrapper's XDG_DATA_DIRS, so the gate
    # is live.) dconf's GIO module is likewise already in that wrapper, so a
    # system-wide default here is enough -- the session needs no extra env.
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
      gdm.enable = true; # Wayland-only as of GNOME 50; no toggle to set
      autoLogin = {
        enable = true;
        user = "tablet";
      };
    };
  };
}
