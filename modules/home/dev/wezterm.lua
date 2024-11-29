local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.font = wezterm.font_with_fallback({
	"MesloLGMDZ Nerd Font Mono",
})
--TODO: Keep this here until this issue is resolved: https://github.com/wez/wezterm/issues/5990
config.front_end = "WebGpu"

return config
