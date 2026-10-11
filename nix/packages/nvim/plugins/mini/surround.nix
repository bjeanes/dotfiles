# https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-surround.md
# https://github.com/echasnovski/mini.nvim/blob/main/doc/mini-surround.txt
{
  plugins.mini = {
    modules = {
      surround = {
        mappings = {
          # mappings more like (n)vim-surround
          delete = "ds";
          add = "S";
          replace = "cs";
        };
      };
    };
  };
}
