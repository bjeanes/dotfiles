{ lib, ... }:
{
  catppuccin = {
    enable = lib.mkDefault true;
    flavor = lib.mkDefault "mocha";
  };

  programs.wezterm.extraConfig = # lua
    ''
      function get_appearance()
        if wezterm.gui then
          return wezterm.gui.get_appearance()
        end
        return 'Dark'
      end

      function scheme_for_appearance(appearance)
        if appearance:find 'Dark' then
          return 'Catppuccin Mocha'
        else
          return 'Catppuccin Latte'
        end
      end

      config.color_scheme = scheme_for_appearance(get_appearance())
    '';

  programs.bat.config.theme = "Catppuccin Mocha";

  programs.ghostty.settings.theme = "dark:catppuccin-mocha,light:catppuccin-latte";
}
