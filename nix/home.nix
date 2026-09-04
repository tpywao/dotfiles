{ config, pkgs, ai-tools-pkgs, ... }:

let
  username = builtins.getEnv "USER";
  homeDirectory = builtins.getEnv "HOME";
in
{
  # マシン固有モジュールは flake.nix の homeConfigurations から注入される

  home.username = username;
  home.homeDirectory = homeDirectory;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;
}
