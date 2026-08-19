#!/bin/bash
is_cmd_exists() {
  command -v $1 >/dev/null 2>&1
}

# os
# $OSTYPE は bash/zsh 固有で POSIX sh (dash 等) では未設定のため使わない。
# uname は source 時に 1 回だけ実行してキャッシュする
# (zsh/.zshenv から全 zsh 起動で source されるので、呼び出しごとの fork を避ける)
_dotfiles_uname_s="$(uname -s)"
is_wsl() {
  is_cmd_exists wslpath
}
is_mac() {
  [ "$_dotfiles_uname_s" = "Darwin" ]
}
is_linux() {
  # WSL も Linux 扱い。区別が必要な場面では is_wsl を先に判定する
  [ "$_dotfiles_uname_s" = "Linux" ]
}

# claude -p へ引数を丸投げする。prompt は単一 positional のため "$*" で結合し、
# 未クオートの複数語をそのまま渡せるようにする (フラグを渡したい場合は claude を直接使う)
# 軽量 Q&A 用途のため haiku + ツール/MCP/セッション保存なしでトークン消費を抑える。
# --bare は認証が ANTHROPIC_API_KEY 限定になる (OAuth 不可) ため使わない
ask() {
  claude -p --model haiku --tools "" --strict-mcp-config --no-session-persistence "$*"
}
