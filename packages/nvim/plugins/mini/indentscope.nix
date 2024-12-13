# https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-indentscope.md
{
  plugins.mini = {
    modules.indentscope = {
      draw.animation.__raw = # lua
        ''
          require('mini.indentscope').gen_animation.none()
        '';
      options.try_as_border = true;
    };
  };
}
