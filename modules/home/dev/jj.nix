# TODO https://gist.github.com/ilyagr/5d6339fb7dac5e7ab06fe1561ec62d45
{pkgs,...}:{
  programs.jujutsu.enable = true;

  home.packages = with pkgs; [
    gg-jj
    lazyjj
  ];
}
