# HOMEBREW_PREFIX は brew shellenv 自身が export するので、
# 設定済みならネストしたシェルでは brew の外部プロセス起動を省略できる
if [[ -z $HOMEBREW_PREFIX && -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Homebrew (cask管理のために維持)
# brew 未導入なら HOMEBREW_PREFIX は空で、(N-/) により候補ごと消える
fpath=(
  $HOMEBREW_PREFIX/share/zsh/site-functions(N-/)
  $fpath
)

# nixpkgs のツールが使う CA バンドル。no_global_rcs で nix-daemon.sh を読まないため
# 未設定のままだと flake.lock と無関係な既定の CA が使われ、nixpkgs の cacert が
# 失効させたルートを信頼し続ける。
# Linux はディストリの CA ストア（社内 CA の追加先）を優先したいので対象外。
if [[ -z $NIX_SSL_CERT_FILE && -r $HOME/.nix-profile/etc/ssl/certs/ca-bundle.crt ]]; then
  export NIX_SSL_CERT_FILE=$HOME/.nix-profile/etc/ssl/certs/ca-bundle.crt
fi
