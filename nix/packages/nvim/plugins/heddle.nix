# Language servers via heddle in repos with a .heddle.toml
{ inputs, system, ... }:
{
  extraPlugins = [ inputs.heddle.packages.${system}.vim-plugin ];
  extraConfigLua = ''
    require("heddle").setup()
  '';
}
