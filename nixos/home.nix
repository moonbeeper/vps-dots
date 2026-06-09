{ pkgs, ... }:
{
  home.username = "moon";
  home.homeDirectory = "/home/moon";

  home.packages = with pkgs; [
    eza
    croc
    fastfetch
  ];
  programs.home-manager.enable = true;

  programs.fish.shellAliases = {
    ls = "eza";
    ll = "eza -l";
    la = "eza -la";
    vi = "nvim";
    vim = "nvim";
  };

  home.stateVersion = "26.05";
}
