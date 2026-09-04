{ config, pkgs, ai-tools-pkgs, dwt-pkgs, ... }:

{
  imports = [
    ./common.nix
  ];

  # マシン固有: aarch64-darwin への ai-tools 統合
  # home.packages はリスト型オプションで common.nix の定義と自動的に concat される
  home.packages = [
    # ccusage / codegraph は package-lock.json で固定した単一 derivation
    ai-tools-pkgs.ai-tools
    ai-tools-pkgs.ax
    ai-tools-pkgs.actionlint
    # worktree コンテナへの docker exec ラッパー。設定は利用先の .envrc で注入する
    dwt-pkgs.default
  ];
}
