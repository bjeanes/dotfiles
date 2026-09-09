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

    # On-screen keyboard. --auto shows/hides it on text-field focus via
    # zwp_input_method_v2, which sway implements; there is no physical
    # keyboard and no toggle affordance on a wall panel, so auto is the only
    # workable mode. --hidden keeps it down until the first focus rather than
    # showing at session start.
    #
    # Do NOT pass -H/-L here. wvkbd's layer_surface_configure treats any
    # configure whose size differs from what it asked for as a reason to
    # hide() and show() again:
    #
    #   if (keyboard.w != w || keyboard.h != h) { ...; hide(); show(); return; }
    #
    # Forcing a height sway won't grant verbatim makes that oscillate forever:
    # the process spins recreating its surface (it appears frozen) while the
    # popups it creates each pass -- sized h*2, anchored -h -- pile up on
    # screen as several undismissable stacked keyboards. Letting wvkbd size
    # itself keeps the requested and granted geometry equal, so the branch
    # never fires.
    exec ${lib.getExe pkgs.wvkbd} --auto --hidden --fn "Sans 16"

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
