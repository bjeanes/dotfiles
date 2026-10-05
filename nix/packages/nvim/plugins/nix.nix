{ config, lib, ... }:
{
  plugins = {
    direnv.enable = true;
    nix.enable = true;
    nix-develop.enable = true;
  };

  # direnv reverts to the pre-direnv shell $PATH before applying an .envrc,
  # which drops the bin dirs the nixvim wrapper prepended (LSP servers, etc).
  # After every direnv export, rebuild $PATH as:
  #
  #   direnv-added (devshell/devenv) > nixvim > host (pre-direnv shell)
  #
  # The host $PATH comes from `direnv exec /`, which unloads the current
  # .envrc; anything in the current $PATH not in that (or nixvim's) was added
  # by direnv.
  autoGroups.nixvim-path = { };
  autoCmd = [
    {
      event = "User";
      pattern = "DirenvLoaded";
      group = "nixvim-path";
      callback.__raw = # lua
        ''
          function()
            local nixvim = vim.split(${lib.nixvim.toLuaObject (lib.makeBinPath config.extraPackages)}, ":")
            local nixvim_after = vim.split(${lib.nixvim.toLuaObject (lib.makeBinPath config.extraPackagesAfter)}, ":", { trimempty = true })

            local res = vim.system(
              { ${lib.nixvim.toLuaObject (lib.getExe config.dependencies.direnv.package)}, "exec", "/", "printenv", "PATH" },
              { text = true }
            ):wait()
            if res.code ~= 0 then
              return
            end

            local split = function(s)
              return vim.split(s or "", ":", { trimempty = true })
            end
            local ours, host = {}, {}
            for _, d in ipairs(vim.list_extend(vim.list_extend({}, nixvim), nixvim_after)) do
              ours[d] = true
            end
            for _, d in ipairs(split(res.stdout:gsub("%s+$", ""))) do
              host[d] = true
            end

            local added, base = {}, {}
            for _, d in ipairs(split(vim.env.PATH)) do
              if not ours[d] then
                table.insert(host[d] and base or added, d)
              end
            end

            vim.env.PATH = table.concat(vim.iter({ added, nixvim, base, nixvim_after }):flatten():totable(), ":")
          end
        '';
    }
  ];
}
