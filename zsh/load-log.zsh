# 設定の読み込み開始/終了ログを出すヘルパー。
# 対話シェルのときだけ出力し、非対話（スクリプト実行）では何もしない。
zmodload zsh/datetime

# _load_begin <名前> [進行中の語] [完了の語]
# 語は活用済みの形で渡す。動詞から -ing / -ed を組み立てると語によって崩れる。
_load_begin() {
  [[ -o interactive ]] || return 0
  _load_name=$1
  _load_ing=${2:-loading}
  _load_ed=${3:-loaded}
  _load_start=$EPOCHREALTIME
  print -r -- "$_load_name: $_load_ing..."
}

_load_end() {
  [[ -o interactive ]] || return 0
  printf '%s: %s (%.0fms)\n' "$_load_name" "$_load_ed" "$(( (EPOCHREALTIME - _load_start) * 1000 ))"
}
