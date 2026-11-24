# ssm-pf: AWS Session Manager のポートフォワードを fzf で選んで起動・停止する
#
# 接続の定義を 1 行 1 接続で標準入力に渡す。空行と # で始まる行は読み飛ばす。
#
#   <名前> <リージョン> <踏み台のインスタンス ID> <接続先ホスト> <接続先ポート> <ローカルポート>
#
# 定義はマシン固有なので dotfiles には置かない。~/.local/zsh/ に呼び出し用の関数を作る:
#
#   mydb() {
#     ssm-pf mydb <<'EOF'
#   db-prod ap-northeast-1 i-0123456789abcdef0 db.example.internal 5432 15432
#   EOF
#   }
#
# 第 1 引数は fzf のプロンプトと案内文に出す名前。
# 起動中かどうかはローカルポートの LISTEN で判定するので、ssm-pf の外で起動した接続も起動中と扱う。

_ssm_pf_log_dir() {
  print -r -- ${XDG_CACHE_HOME:-$HOME/.cache}/ssm-pf
}

# ローカルポートを LISTEN しているプロセスの pid
_ssm_pf_listening() {
  lsof -t -iTCP:$1 -sTCP:LISTEN 2>/dev/null
}

# ps の etime（[[dd-]hh:]mm:ss）を「N分」「N時間M分」にする
_ssm_pf_elapsed() {
  local e=${1// /} d=0 h=0 m=0
  [[ -n $e ]] || return 1
  if [[ $e == *-* ]]; then d=${e%%-*}; e=${e#*-}; fi
  local -a p=(${(s.:.)e})
  if (( $#p == 3 )); then h=$p[1] m=$p[2]; else m=$p[1]; fi
  h=$(( 10#$h + 24 * 10#$d )) m=$(( 10#$m ))
  if (( h )); then print "${h}時間${m}分"; else print "${m}分"; fi
}

# 一覧の取得: 定義（標準入力）の各行に状態を足す
#   <定義の 6 列> <up|down> <経過時間（down のときは ->）>
_ssm_pf_list() {
  local name region target host rport lport rest elapsed
  local -a pids
  while read -r name region target host rport lport rest; do
    [[ -z $name || $name == \#* ]] && continue
    pids=($(_ssm_pf_listening $lport))
    if (( $#pids )); then
      elapsed=$(_ssm_pf_elapsed "$(ps -o etime= -p $pids[1] 2>/dev/null)")
      print -r -- "$name $region $target $host $rport $lport up ${elapsed:--}"
    else
      print -r -- "$name $region $target $host $rport $lport down -"
    fi
  done
}

# 一覧の表示: _ssm_pf_list の出力（標準入力）を表示用の行にする。行頭は接続の名前
_ssm_pf_format() {
  local line name region target host rport lport state elapsed width=0
  local -a rows=(${(f)"$(cat)"})
  for line in $rows; do
    name=${line%% *}
    (( $#name > width )) && width=$#name
  done
  for line in $rows; do
    read -r name region target host rport lport state elapsed <<<"$line"
    if [[ $state == up ]]; then
      printf "%-${width}s  起動中  localhost:%s  %s\n" $name $lport $elapsed
    else
      printf "%-${width}s  停止中  localhost:%s\n" $name $lport
    fi
  done
}

# 一覧から選ぶ: 表示用の行（標準入力）を fzf で選び、接続の名前を 1 行ずつ返す
_ssm_pf_select() {
  local label=$1
  fzf --multi --reverse \
    --prompt "[$label] Enter で起動/停止を切り替え > " \
    --preview "cat $(_ssm_pf_log_dir)/{1}.log 2>/dev/null || echo ログなし" \
    --preview-window down,6 | awk '{print $1}'
}

# 定義（標準入力）から名前が一致する行を返す
_ssm_pf_find() {
  local name rest
  while read -r name rest; do
    [[ $name == "$1" ]] && { print -r -- "$name $rest"; return 0 }
  done
  return 1
}

# 起動: バックグラウンドで起動し、ローカルポートの LISTEN が始まるまで待つ。
# 待つ間に aws が終了したら（認証切れ・権限不足・踏み台の停止など）ログを表示して失敗を返す
#   _ssm_pf_up <label> <定義の 6 列>
_ssm_pf_up() {
  local label=$1 name=$2 region=$3 target=$4 host=$5 rport=$6 lport=$7
  local log=$(_ssm_pf_log_dir)/$name.log pid i
  local tries=$(( ${SSM_PF_TIMEOUT:-15} * 4 ))

  mkdir -p ${log:h}
  # stdin を切らないと session-manager-plugin が端末の入力待ちで止まる
  aws ssm start-session --region $region --target $target \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"$host\"],\"portNumber\":[\"$rport\"],\"localPortNumber\":[\"$lport\"]}" \
    </dev/null >$log 2>&1 &!
  pid=$!

  for (( i = 0; i < tries; i++ )); do
    if _ssm_pf_listening $lport >/dev/null; then
      print "$name: localhost:$lport で待ち受け開始（終了: $label で選択 / ログ: $log）"
      return 0
    fi
    if ! kill -0 $pid 2>/dev/null; then
      print -u2 "$name: 起動に失敗した。aws の認証（aws login など）を確認する"
      cat $log >&2
      return 1
    fi
    sleep 0.25
  done

  print -u2 "$name: ${SSM_PF_TIMEOUT:-15} 秒待っても localhost:$lport の待ち受けが始まらない（ログ: $log）"
  return 1
}

# 選んだ接続の動作: 起動中なら止め、止まっていれば起動する。
# 止めるのはローカルポートを LISTEN している session-manager-plugin（親の aws も続けて終了する）
#   _ssm_pf_toggle <label> <定義の 6 列>
_ssm_pf_toggle() {
  local name=$2 lport=$7
  local -a pids=($(_ssm_pf_listening $lport))
  if (( $#pids )); then
    kill $pids && print "$name: 停止した"
  else
    _ssm_pf_up "$@"
  fi
}

ssm-pf() {
  local label=$1 defs name ret=0
  local -a selected def
  if [[ -z $label || -t 0 ]]; then
    print -u2 "usage: ssm-pf <名前> < 接続の定義（1 行 1 接続: 名前 リージョン 踏み台 接続先ホスト 接続先ポート ローカルポート）"
    return 2
  fi
  defs=$(cat)
  selected=($(print -r -- $defs | _ssm_pf_list | _ssm_pf_format | _ssm_pf_select $label))
  for name in $selected; do
    def=($(print -r -- $defs | _ssm_pf_find $name))
    _ssm_pf_toggle $label $def[1,6] || ret=1
  done
  return $ret
}
