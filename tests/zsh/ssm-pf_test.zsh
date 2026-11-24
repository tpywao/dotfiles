#! /usr/bin/env zsh -f
# zsh/ssm-pf.zsh を検証する。
#
#   zsh tests/zsh/ssm-pf_test.zsh
#
# aws・lsof・ps・kill・fzf を関数のスタブに差し替える。LISTEN の状態は $tmp/listen/<port>
# （中身は pid）で表す。ネットワークへは出ず、実際のプロセスも止めない。

DOTFILES=${0:A:h:h:h}

pass_count=0
fail_count=0

pass() {
  pass_count=$((pass_count + 1))
}

fail() {
  fail_count=$((fail_count + 1))
  printf 'FAIL  %s\n' "$1"
}

# assert_eq <期待値> <実際値> <ラベル>
assert_eq() {
  if [[ "$1" == "$2" ]]; then
    pass
  else
    fail "$3: expected=$1 actual=$2"
  fi
}

# assert_match <期待するグロブ> <実際値> <ラベル>
assert_match() {
  if [[ "$2" == ${~1} ]]; then
    pass
  else
    fail "$3: expected to match=$1 actual=$2"
  fi
}

tmp=$(mktemp -d)
trap 'rm -r "$tmp"' EXIT
export XDG_CACHE_HOME=$tmp/cache

source "$DOTFILES/zsh/ssm-pf.zsh"

# --- スタブ ---

# lsof -t -iTCP:<port> -sTCP:LISTEN
# 本物と同じく、該当が無ければ 1 を返す（_ssm_pf_up は終了コードで LISTEN を判定する）
lsof() {
  local arg port
  for arg; do [[ $arg == -iTCP:* ]] && port=${arg#-iTCP:}; done
  [[ -f $tmp/listen/$port ]] || return 1
  cat $tmp/listen/$port
}

# ps -o etime= -p <pid>
ps() {
  print -r -- "${STUB_ETIME:-   05:00}"
}

# kill -0 は本物へ回す（_ssm_pf_up が起動した aws の生存確認に使う）。
# それ以外は止めた pid を記録し、その pid の LISTEN を消すだけにする
kill() {
  if [[ $1 == -0 ]]; then
    builtin kill "$@"
    return
  fi
  local pid f
  for pid; do
    print -r -- $pid >> $tmp/killed
    for f in $tmp/listen/*(N); do
      [[ $(< $f) == $pid ]] && rm $f
    done
  done
}

# STUB_AWS=ok: 引数を記録し、localPortNumber の LISTEN を作って終わる
# STUB_AWS=fail: 認証エラーを出して終わる
# STUB_AWS=hang: LISTEN を作らずに待ち続ける
aws() {
  print -r -- "$*" >> $tmp/aws_args
  case $STUB_AWS in
    ok)
      [[ $* =~ 'localPortNumber":\["([0-9]+)"' ]] || return 1
      print 4242 > $tmp/listen/$match[1]
      ;;
    fail)
      print -u2 'Unable to locate credentials. You can configure credentials by running "aws login".'
      return 255
      ;;
    hang)
      sleep 3
      ;;
  esac
}

# 入力を記録し、STUB_PICK に一致する名前の行だけを選んだことにする
fzf() {
  local line
  print -r -- "$*" > $tmp/fzf_args
  : > $tmp/fzf_in
  while IFS= read -r line; do
    print -r -- $line >> $tmp/fzf_in
    [[ -n $STUB_PICK && ${line%% *} == ${~STUB_PICK} ]] && print -r -- $line
  done
  return 0
}

reset_state() {
  rm -rf $tmp/listen $tmp/killed $tmp/aws_args $tmp/fzf_in $tmp/fzf_args
  mkdir -p $tmp/listen
  unset STUB_AWS STUB_PICK STUB_ETIME SSM_PF_TIMEOUT
}

defs='# コメント行
db-a ap-northeast-1 i-aaa a.example.internal 5432 15432

db-long us-east-1 i-bbb b.example.internal 3306 13306'

# --- _ssm_pf_elapsed ---
assert_eq "0分" "$(_ssm_pf_elapsed '   00:07')" "elapsed: 1 分未満"
assert_eq "9分" "$(_ssm_pf_elapsed '   09:08')" "elapsed: 先頭ゼロの分"
assert_eq "1時間2分" "$(_ssm_pf_elapsed '01:02:03')" "elapsed: 時間あり"
assert_eq "51時間4分" "$(_ssm_pf_elapsed '2-03:04:05')" "elapsed: 日またぎは時間に足す"
_ssm_pf_elapsed ''
assert_eq "1" "$?" "elapsed: 空なら失敗"

# --- _ssm_pf_list: コメントと空行を読み飛ばし、状態と経過時間を足す ---
reset_state
print 100 > $tmp/listen/15432
STUB_ETIME='01:02:03'
out=$(print -r -- $defs | _ssm_pf_list)
assert_eq "db-a ap-northeast-1 i-aaa a.example.internal 5432 15432 up 1時間2分
db-long us-east-1 i-bbb b.example.internal 3306 13306 down -" "$out" "list: 起動中と停止中"

# --- _ssm_pf_format: 名前の幅をそろえ、起動中だけ経過時間を出す ---
out=$(print -r -- $out | _ssm_pf_format)
assert_eq "db-a     起動中  localhost:15432  1時間2分
db-long  停止中  localhost:13306" "$out" "format: 表示行"

# --- ssm-pf: 停止中を選ぶと起動する ---
reset_state
STUB_AWS=ok STUB_PICK=db-long
out=$(print -r -- $defs | ssm-pf mylabel 2>&1)
assert_eq "0" "$?" "起動: 終了コード"
assert_eq "db-long: localhost:13306 で待ち受け開始（終了: mylabel で選択 / ログ: $tmp/cache/ssm-pf/db-long.log）" "$out" "起動: 案内文"
assert_match "*--region us-east-1 --target i-bbb *\"host\":\[\"b.example.internal\"\],\"portNumber\":\[\"3306\"\],\"localPortNumber\":\[\"13306\"\]*" "$(< $tmp/aws_args)" "起動: aws に渡す引数"
assert_match "*\[mylabel\]*" "$(< $tmp/fzf_args)" "起動: プロンプトに名前を出す"

# --- ssm-pf: 起動中を選ぶと止める ---
reset_state
print 100 > $tmp/listen/15432
STUB_PICK=db-a
out=$(print -r -- $defs | ssm-pf mylabel 2>&1)
assert_eq "db-a: 停止した" "$out" "停止: 案内文"
assert_eq "100" "$(< $tmp/killed)" "停止: LISTEN している pid を止める"
assert_eq "0" "$(ls $tmp/aws_args 2>/dev/null | wc -l | tr -d ' ')" "停止: aws を呼ばない"

# --- ssm-pf: 複数選ぶとそれぞれ切り替える ---
reset_state
print 100 > $tmp/listen/15432
STUB_AWS=ok STUB_PICK='db-*'
out=$(print -r -- $defs | ssm-pf mylabel 2>&1)
assert_match "db-a: 停止した
db-long: localhost:13306 で待ち受け開始*" "$out" "複数: 停止と起動"

# --- ssm-pf: aws が終了したらログを出して失敗を返す ---
reset_state
STUB_AWS=fail STUB_PICK=db-a
out=$(print -r -- $defs | ssm-pf mylabel 2>&1)
assert_eq "1" "$?" "起動失敗: 終了コード"
assert_match "db-a: 起動に失敗した。*
Unable to locate credentials.*" "$out" "起動失敗: aws のエラーを表示する"

# --- ssm-pf: 待ち受けが始まらないままならタイムアウト ---
reset_state
STUB_AWS=hang STUB_PICK=db-a SSM_PF_TIMEOUT=1
out=$(print -r -- $defs | ssm-pf mylabel 2>&1)
assert_eq "1" "$?" "タイムアウト: 終了コード"
assert_match "db-a: 1 秒待っても localhost:15432 の待ち受けが始まらない*" "$out" "タイムアウト: 案内文"

# --- ssm-pf: 何も選ばなければ何もしない ---
reset_state
STUB_AWS=ok
out=$(print -r -- $defs | ssm-pf mylabel 2>&1)
assert_eq "0" "$?" "選択なし: 終了コード"
assert_eq "" "$out" "選択なし: 出力なし"
assert_eq "0" "$(ls $tmp/aws_args 2>/dev/null | wc -l | tr -d ' ')" "選択なし: aws を呼ばない"

# --- ssm-pf: 名前を渡さなければ使い方を出す ---
out=$(print -r -- $defs | ssm-pf 2>&1)
assert_eq "2" "$?" "引数なし: 終了コード"
assert_match "usage: ssm-pf *" "$out" "引数なし: 使い方"

printf '\n%d passed, %d failed\n' "$pass_count" "$fail_count"
[[ $fail_count -eq 0 ]]
