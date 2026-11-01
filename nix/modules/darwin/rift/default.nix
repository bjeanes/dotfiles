{
  config,
  lib,
  pkgs,
  perSystem,
  ...
}:
let
  cfg = config.services.rift;
  configFile = (pkgs.formats.toml { }).generate "rift.toml" cfg.settings;
  workspaces = lib.range 1 9;
in
{
  options.services.rift = {
    enable = lib.mkEnableOption "the Rift tiling window manager";
    package = lib.mkOption {
      type = lib.types.package;
      default = perSystem.self.rift;
    };
    settings = lib.mkOption {
      inherit (pkgs.formats.toml { }) type;
      default = { };
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(cfg.enable && config.services.paneru.enable);
          message = "services.rift and services.paneru both manage every window; enable only one.";
        }
      ];

      # Mirrors the Paneru module as closely as Rift allows.
      services.rift.settings = {
        settings = {
          animate = true;
          # The default config's "0.0 = refresh rate" fails validation.
          animation_fps = 120.0; # ProMotion
          default_disable = false; # manage every Space, like Paneru
          focus_follows_mouse = true;
          mouse_follows_focus = true;
          mouse_hides_on_focus = false;
          # Mouse warp treats displays stacked top-to-bottom as left-to-right.
          horizontal_mouse_warp = "top-to-bottom";
          # The config is in the store. A change takes effect when nix-darwin
          # reloads the agent.
          hot_reload = false;

          layout = {
            mode = "scrolling";
            scrolling = {
              # Not covered by settings.animate.
              animate = true;
              preset_column_widths = config.services.paneru.settings.options.preset_column_widths;
              min_column_width_ratio = 0.2;
              max_column_width_ratio = 1.0;
              focus_navigation_style = "niri";
              gestures = {
                enabled = true;
                fingers = 3;
                invert_horizontal = true; # natural direction, like Paneru
              };
            };
            # Paneru pads each window by 8, so 16 between windows and 8 at edges.
            gaps = {
              outer = lib.genAttrs [ "top" "left" "bottom" "right" ] (_: 8);
              inner = {
                horizontal = 16;
                vertical = 16;
              };
            };
          };
        };

        virtual_workspaces = {
          mode = "per_display";
          default_workspace_count = 9;
          workspace_names = map toString workspaces;
          app_rules = [
            {
              app_id = "com.apple.Stickies";
              floating = true;
            }
          ];
        };

        # Caps Lock is Ctrl, so "mod" is Caps+Option, as with Paneru.
        modifier_combinations = {
          mod = "Ctrl + Alt";
          modShift = "Ctrl + Alt + Shift";
          modCmd = "Ctrl + Alt + Meta";
          modCmdShift = "Ctrl + Alt + Meta + Shift";
        };

        keys = {
          "mod + H".move_focus = "left";
          "mod + J".move_focus = "down";
          "mod + K".move_focus = "up";
          "mod + L".move_focus = "right";
          "modShift + H".move_node = "left";
          "modShift + J".move_node = "down";
          "modShift + K".move_node = "up";
          "modShift + L".move_node = "right";

          "mod + Equal" = "switch_preset_column_width";
          "mod + Minus".switch_preset_column_width.backwards = true;
          "modShift + Equal".resize_window_grow = "vertical";
          "modShift + Minus".resize_window_shrink = "vertical";
          "mod + Enter" = "toggle_fullscreen_within_gaps";
          "modShift + F" = "toggle_fullscreen_within_gaps";
          "mod + C" = "center_selection";
          "modShift + B" = "balance";
          "mod + R" = "balance";

          "mod + BracketLeft".consume_or_expel_window = "left";
          "mod + BracketRight".consume_or_expel_window = "right";
          # Card stacks with a tab bar only exist in the traditional layout; in
          # scrolling, toggle_stack merges the next column into this one.
          "mod + T" = "toggle_stack";
          "modShift + T".set_workspace_layout.mode = "traditional";
          "modShift + S".set_workspace_layout.mode = "scrolling";
          "modShift + Space" = "toggle_window_floating";
          "modShift + R" = "toggle_focus_floating";

          "modCmd + H".focus_display = "left";
          "modCmd + J".focus_display = "down";
          "modCmd + K".focus_display = "up";
          "modCmd + L".focus_display = "right";
          "modCmdShift + H".move_window_to_display.selector = "left";
          "modCmdShift + J".move_window_to_display.selector = "down";
          "modCmdShift + K".move_window_to_display.selector = "up";
          "modCmdShift + L".move_window_to_display.selector = "right";
          "modCmd + Left".move_workspace_to_display.selector = "left";
          "modCmd + Down".move_workspace_to_display.selector = "down";
          "modCmd + Up".move_workspace_to_display.selector = "up";
          "modCmd + Right".move_workspace_to_display.selector = "right";

          "modCmd + R" = "reload_config";
          "modCmd + Q" = "save_and_exit";
        }
        // lib.listToAttrs (
          lib.concatMap (n: [
            (lib.nameValuePair "mod + ${toString n}" { switch_to_workspace = n - 1; })
            (lib.nameValuePair "modShift + ${toString n}" {
              move_window_to_workspace = {
                workspace = n - 1;
                follow = true;
              };
            })
          ]) workspaces
        );
      };
    }

    (lib.mkIf cfg.enable {
      environment.systemPackages = [ cfg.package ];

      # Same label as `rift service install`, so the two can't run side by side.
      launchd.user.agents.rift.serviceConfig = {
        Label = "git.acsandmann.rift";
        ProgramArguments = [
          (lib.getExe cfg.package)
          "--config"
          "${configFile}"
        ];
        KeepAlive = {
          Crashed = true;
          SuccessfulExit = false;
        };
        ProcessType = "Interactive";
        RunAtLoad = true;
        StandardOutPath = "/tmp/rift.log";
        StandardErrorPath = "/tmp/rift.err.log";
      };
    })
  ];
}
