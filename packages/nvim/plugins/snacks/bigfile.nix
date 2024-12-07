# bigfile adds a new filetype bigfile to Neovim that triggers when the
# file is larger than the configured size. This automatically prevents
# things like LSP and Treesitter attaching to the buffer.
#
# https://github.com/folke/snacks.nvim/blob/main/docs/bigfile.md
{
  plugins.snacks.settings.bigfile.enabled = true;
}
