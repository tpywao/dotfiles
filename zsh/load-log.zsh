# 設定の読み込み開始/終了ログを出すヘルパー。
# 対話シェルのときだけ出力し、非対話（スクリプト実行）では何もしない。
zmodload zsh/datetime

_load_begin() {
  [[ -o interactive ]] || return 0
  _load_name=$1
  _load_start=$EPOCHREALTIME
  print -r -- "$_load_name: loading..."
}

_load_end() {
  [[ -o interactive ]] || return 0
  printf '%s: loaded (%.0fms)\n' "$_load_name" "$(( (EPOCHREALTIME - _load_start) * 1000 ))"
}
