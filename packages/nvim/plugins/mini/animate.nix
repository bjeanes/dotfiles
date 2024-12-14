# https://github.com/echasnovski/mini.animate
let
  timing = ms: 
    let
      msS = builtins.toString ms;
    in 
    {
    __raw = # lua
    ''
      -- Animate only for ${msS}ms
      require('mini.animate').gen_timing.linear({
        duration = ${msS},
        unit = 'total'
      })
    '';
  };
in
{
  plugins.mini = {
    modules.animate = {
      cursor.enable = false;

      scroll.timing = timing 100;
      resize.timing = timing 100;

      # https://github.com/echasnovski/mini.nvim/issues/357#issuecomment-1578277149
      open.enable = false;
      close.enable = false;
    };
  };
}


