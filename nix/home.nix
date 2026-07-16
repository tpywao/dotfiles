{ config, pkgs, ai-tools, ... }:

let
  username = builtins.getEnv "USER";
in
{
  imports = [
    ./work-mac.nix  # マシン固有設定（common.nix も imports）
  ];

  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;
}
