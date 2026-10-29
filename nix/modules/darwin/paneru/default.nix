{ inputs, lib, ... }:
let
  # Caps Lock is Ctrl, so this is Caps+Option. Plain Option stays free for
  # compose keys and special characters.
  mod = "ctrl + alt";
  workspaces = lib.range 1 9;
in
{
  imports = [ inputs.paneru.darwinModules.paneru ];

  # With Lua on, upstream always wraps the binary in a bash script, and macOS
  # then grants Accessibility to bash rather than paneru.
  services.paneru.luaConfig.enable = false;

  services.paneru.settings = {
    options = {
      focus_follows_mouse = true;
      mouse_follows_focus = true;
      preset_column_widths = [
        0.2
        0.25
        0.33
        0.4
        0.5
        0.6
        0.66
        0.75
        0.8
        1.0
      ];
      window_resize_cycle = false;
      # animation_speed unset: moves and resizes are instant.
      mouse_resize_modifier = mod;
      # Displays stacked top-to-bottom in macOS read as left-to-right.
      horizontal_mouse_warp = -1;
    };

    swipe = {
      continuous = false;
      gesture = {
        fingers_count = 3;
        direction = "Natural";
        vertical = true;
      };
      scroll.modifier = "alt + shift";
    };

    decorations = {
      # Experimental overlay mode: grey flattens light and dark windows alike.
      inactive.dim = {
        opacity = 0.25;
        color = "#808080";
      };
      active.border = {
        enabled = true;
        color = "#FF555D";
        width = 2.5;
      };
    };

    windows = {
      all = {
        title = ".*";
        horizontal_padding = 8;
        vertical_padding = 8;
      };
      stickies = {
        title = ".*";
        bundle_id = "com.apple.Stickies";
        floating = true;
      };
    };

    bindings = {
      window_focus_west = "${mod} - h";
      window_focus_south = "${mod} - j";
      window_focus_north = "${mod} - k";
      window_focus_east = "${mod} - l";
      window_swap_west = "${mod} + shift - h";
      window_swap_south = "${mod} + shift - j";
      window_swap_north = "${mod} + shift - k";
      window_swap_east = "${mod} + shift - l";
      window_focus_managed = "${mod} - tab";
      window_focus_first = "${mod} - comma";
      window_focus_last = "${mod} - period";
      window_swap_first = "${mod} + shift - comma";
      window_swap_last = "${mod} + shift - period";

      # Paneru only steps through preset_column_widths; there is no ±N% resize.
      window_resize = "${mod} - equal";
      window_shrink = "${mod} - minus";
      window_vertical_grow = "${mod} + shift - equal";
      window_vertical_shrink = "${mod} + shift - minus";
      window_fullwidth = [
        "${mod} - return"
        "${mod} + shift - f"
      ];
      window_center = "${mod} - c";
      window_balance = "${mod} + shift - b";
      window_equalize = "${mod} - r";

      window_stack = "${mod} - leftbracket";
      window_unstack = "${mod} - rightbracket";
      window_tabbeddisplay = "${mod} - t";
      window_manage = "${mod} + shift - space";
      window_raise_floating = "${mod} + shift - r";

      mouse_nextdisplay = "ctrl + cmd - tab";
      window_nextdisplay = "ctrl + cmd + shift - tab";

      restart = "${mod} + cmd - r";
      quit = "${mod} + cmd - q";
    }
    // lib.listToAttrs (
      lib.concatMap (n: [
        (lib.nameValuePair "window_virtualnum_${toString n}" "${mod} - ${toString n}")
        (lib.nameValuePair "window_virtualmovenum_${toString n}" "${mod} + shift - ${toString n}")
      ]) workspaces
    );
  };
}
