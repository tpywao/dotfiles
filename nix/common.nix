# ~/.dotfiles/nix/common.nix
{ config, pkgs, ... }:

{
  # 全マシン共通のパッケージリスト
  home.packages = import ./packages.nix pkgs;

  # direnv + nix-direnv（use flake の評価結果をキャッシュして高速化）
  # stdlib は未設定のまま: ~/.config/direnv/direnvrc を生成させず、
  # install.sh が張る ~/.direnvrc（gcloud 関数）を direnv に読ませ続けるため
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.home-manager.enable = true;
}
