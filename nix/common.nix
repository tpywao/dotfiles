# ~/.dotfiles/nix/common.nix
{ config, pkgs, ... }:

{
  # 全マシン共通のパッケージリスト
  home.packages = import ./packages.nix pkgs;

  programs.home-manager.enable = true;
}
