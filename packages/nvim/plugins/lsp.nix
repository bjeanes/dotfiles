{ lib, pkgs, ... }:
{
  plugins.lspconfig.enable = true;

  # Neovim applies `documentChanges` (including file renames) but doesn't
  # advertise it, nor send `workspace/willRenameFiles`, so servers that move
  # files on rename (e.g. clojure-lsp namespaces) refuse or half-apply it.
  lsp.luaConfig.content = ''
    local rename = vim.lsp.util.rename
    vim.lsp.util.rename = function(old, new, opts)
      Snacks.rename.on_rename_file(old, new, function()
        rename(old, new, opts)
      end)
    end
  '';

  lsp.servers = {
    clojure_lsp = {
      enable = true;
      config.capabilities.workspace.workspaceEdit.documentChanges = true;
    };
    expert = {
      enable = true;
      package = pkgs.beamPackages.expert;
    };
    nixd = {
      enable = true;
      config.settings.nixd.formatting.command = [ (lib.getExe pkgs.nixfmt) ];
    };
    ruby_lsp.enable = true;
    rust_analyzer.enable = true;
  };

  plugins.which-key.settings.spec = [
    {
      __unkeyed-1 = "<Leader>l";
      group = "LSP";
    }
  ];

  lsp.keymaps =
    lib.mapAttrsToList
      (key: action: {
        inherit key;
        mode = "n";
        lspBufAction = action;
        options.desc = "Lsp buf ${action}";
      })
      {
        "gd" = "definition";
        "gD" = "references";
        "gt" = "type_definition";
        "gi" = "implementation";
        "K" = "hover";
      }
    # Pickers from mini.extra
    ++
      lib.mapAttrsToList
        (key: pick: {
          inherit key;
          mode = "n";
          action = "<Cmd>Pick ${pick.cmd}<CR>";
          options.desc = pick.desc;
        })
        {
          "<Leader>ls" = {
            cmd = "lsp scope='document_symbol'";
            desc = "Document symbols";
          };
          "<Leader>lS" = {
            cmd = "lsp scope='workspace_symbol_live'";
            desc = "Workspace symbols";
          };
          "<Leader>lr" = {
            cmd = "lsp scope='references'";
            desc = "References";
          };
          "<Leader>ld" = {
            cmd = "lsp scope='definition'";
            desc = "Definitions";
          };
          "<Leader>lD" = {
            cmd = "lsp scope='declaration'";
            desc = "Declarations";
          };
          "<Leader>li" = {
            cmd = "lsp scope='implementation'";
            desc = "Implementations";
          };
          "<Leader>lt" = {
            cmd = "lsp scope='type_definition'";
            desc = "Type definitions";
          };
          "<Leader>le" = {
            cmd = "diagnostic scope='current'";
            desc = "Diagnostics (buffer)";
          };
          "<Leader>lE" = {
            cmd = "diagnostic scope='all'";
            desc = "Diagnostics (all)";
          };
        }
    ++ [
      {
        key = "<Leader>la";
        mode = [
          "n"
          "x"
        ];
        lspBufAction = "code_action";
        options.desc = "Code actions";
      }
    ];
}
