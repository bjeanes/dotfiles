{
  autoCmd = [
    {
      event = "FileType";
      pattern = [ "markdown" ];
      # Route `gq` through conform/mdformat so it wraps list items correctly
      # and never splits links or inline code (`gw` is still Vim's built-in).
      # Conform falls back to internal formatting for insert-mode auto-wrap.
      command = "setlocal textwidth=80 formatexpr=v:lua.require'conform'.formatexpr()";
    }
  ];
}
