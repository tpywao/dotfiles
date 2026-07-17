# ~/.dotfiles/nix/work-mac.nix
{ config, pkgs, ai-tools-pkgs, ... }:

{
  imports = [
    ./common.nix
  ];

  # マシン固有: aarch64-darwin への ai-tools 統合
  home.packages = (import ./packages.nix pkgs) ++ [
    ai-tools-pkgs.codegraph
    ai-tools-pkgs.ccusage
    ai-tools-pkgs.repomix
  ];
}
