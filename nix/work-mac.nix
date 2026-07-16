# ~/.dotfiles/nix/work-mac.nix
{ config, pkgs, ai-tools, ... }:

{
  imports = [
    ./common.nix
  ];

  # マシン固有: aarch64-darwin への ai-tools 統合
  home.packages = (import ./packages.nix pkgs) ++ [
    ai-tools.packages.aarch64-darwin.codegraph
    ai-tools.packages.aarch64-darwin.ccusage
    ai-tools.packages.aarch64-darwin.repomix
  ];
}
