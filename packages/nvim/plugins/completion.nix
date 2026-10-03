{
  plugins.blink-cmp = {
    enable = true;

    # Targets the old `plugins.lsp`; blink registers its capabilities via
    # `vim.lsp.config('*')` itself.
    setupLspCapabilities = false;

    settings = {
      # <C-y> accept, <C-n>/<C-p> select, <C-space> open/docs, <C-e> close
      keymap.preset = "default";

      completion.documentation.auto_show = true;
      signature.enabled = true;
    };
  };
}
