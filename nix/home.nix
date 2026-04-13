{ config, pkgs, ... }:

let
  username = builtins.getEnv "USER";
in
{
  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.11";

  home.packages = import ./packages.nix pkgs;

  programs.home-manager.enable = true;
}
