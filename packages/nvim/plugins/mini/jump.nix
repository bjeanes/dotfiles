/*
  Jump to next/previous single character

  Features

  - Extend f, F, t, T to work on multiple lines.
  - Repeat jump by pressing f, F, t, T again. It is reset when cursor moved as
    a result of not jumping or timeout after idle time (duration customizable).
  - Highlight (after customizable delay) all possible target characters and stop
    it after some (customizable) idle time.
  - Normal, Visual, and Operator-pending (with full dot-repeat) modes are supported.

  https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-jump.md
  https://github.com/echasnovski/mini.nvim/blob/main/doc/mini-jump.txt
*/
{
  plugins.mini = {
    modules = {
      jump = { };
    };
  };
}
