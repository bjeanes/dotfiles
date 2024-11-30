local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action

config.font = wezterm.font_with_fallback({
	"MesloLGMDZ Nerd Font Mono",
})
--TODO: Keep this here until this issue is resolved: https://github.com/wez/wezterm/issues/5990
config.front_end = "WebGpu"


config.keys = {
  -- Rebind OPT-Left, OPT-Right as ALT-b, ALT-f respectively to match Terminal.app behavior
  {
    key = 'LeftArrow',
    mods = 'OPT',
    action = act.SendKey {
      key = 'b',
      mods = 'ALT',
    },
  },
  {
    key = 'RightArrow',
    mods = 'OPT',
    action = act.SendKey {
      key = 'f',
      mods = 'ALT'
    },
  },
}

return config
