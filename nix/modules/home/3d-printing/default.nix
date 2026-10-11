{ pkgs, ... }:
{
  config = {
    home.packages = with pkgs; [
      # openscad
    ];
  };
}
