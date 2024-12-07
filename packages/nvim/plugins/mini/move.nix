/*
  Move any selection in any direction

  - Works in two modes:
    - Visual mode: Select text and press customizable mapping to move in all
      four directions (left, right, down, up). It keeps Visual mode.
    - Normal mode: Press customizable mapping to move current line in all four
      directions (left, right, down, up).
  - Special handling of linewise movement:
    - Vertical movement gets reindented with `=`.
    - Horizontal movement is improved indent/outdent with `>` / `<`.
    - Cursor moves along with selection.

  https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-move.md
  https://github.com/echasnovski/mini.nvim/blob/main/doc/mini-move.txt
*/
{
  plugins.mini = {
    modules = {
      move = { };
    };
  };
}
