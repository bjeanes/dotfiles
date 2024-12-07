{
  plugins.lsp = {
    enable = true;

    keymaps = {
      lspBuf = {
        "gd" = "definition";
        "gD" = "references";
        "gt" = "type_definition";
        "gi" = "implementation";
        "K" = "hover";
      };
    };
  };

  plugins.conform-nvim = {
    enable = true;
    settings = {
      default_format_opts.lsp_format = "prefer";
    };
  };
}
