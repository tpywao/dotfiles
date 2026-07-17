# ~/.dotfiles/nix/work-mac.nix
{ config, pkgs, ai-tools-pkgs, ... }:

{
  imports = [
    ./common.nix
  ];

  # マシン固有: aarch64-darwin への ai-tools 統合
  # home.packages はリスト型オプションで common.nix の定義と自動的に concat される
  home.packages = [
    ai-tools-pkgs.codegraph
    ai-tools-pkgs.ccusage
    ai-tools-pkgs.repomix
    ai-tools-pkgs.ax
    ai-tools-pkgs.actionlint
  ];
}
