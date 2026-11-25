#!/bin/sh
# Stop hook: 作業の状態が変わったら、agent-status スキルでシートへ記録するよう促す。
#
# シート（Claude Sheets）は Docs コネクタ経由でモデルしか書けない。hook は記録に使う値を集めて
# additionalContext で渡すところまでを受け持ち、シートへの書き方はスキルに任せる。
#
# 促すのは、そのセッションで初めてのターン終わり、指紋（ブランチ・HEAD・未 push 件数）が
# 変わったとき、前回促してから 30 分以上たったときだけ。stop_hook_active が true のときは
# 何もしないので、続けさせるのは 1 回に限られる。シートを設定していないマシン、claude -p
# （ヘッドレス実行）、jq・git の無い環境、壊れた入力、存在しない cwd では黙って exit 0 で
# 終わる（ターンを終えられなくしてはいけないため）。
#
#   agent-status.sh --collect <session_id>
#
# は cwd の値の一覧だけを出力し、指紋を更新する。モデルが hook の合図を待たずに記録する
# ときに使う（直後の Stop で同じ内容の記録をもう一度促さないよう、指紋も更新する）。
set -u

command -v jq >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

config="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/agent-status-sheet"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/agent-status"

if [ "${1:-}" = --collect ]; then
  session_id=${2:-}
else
  # claude -p（ヘッドレス実行）では促さない。-p は最後のメッセージだけを出力するので、記録のために
  # 続けたターンの出力が本来の答えを置き換えてしまう（utils.bash の ask() などが壊れる）。
  # 2026-11-25 に確かめた時点で、-p では sdk-cli、対話のセッションでは cli だった
  if [ "${CLAUDE_CODE_ENTRYPOINT:-}" = sdk-cli ]; then
    exit 0
  fi
  input=$(cat)
  printf '%s' "$input" | jq -e 'type == "object"' >/dev/null 2>&1 || exit 0
  if [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = true ]; then
    exit 0
  fi
  session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
  if [ -z "$cwd" ] || ! cd "$cwd" 2>/dev/null; then
    exit 0
  fi
fi

# 状態ファイルの名前に使うので、パス区切りなどを含む値は受け付けない
case $session_id in
  '' | *[!A-Za-z0-9_-]*) exit 0 ;;
esac

sheet=$(sed -n 1p "$config" 2>/dev/null)
[ -n "$sheet" ] || exit 0

# --- 値を集める ---
repo=$(basename "$PWD")
branch=
head=
count=0
subject=
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  url=$(git remote get-url origin 2>/dev/null)
  if [ -n "$url" ]; then
    # リポジトリ列は行を探すキーなので、マシンごとの URL の書き方（末尾の / や .git の有無）で
    # 値が変わらないようにする。また、scheme と authority（user:pass@host:port）は先に落とす。
    # 最後の 2 つを取るだけでは、パスが 1 階層の URL でホストと認証情報が owner として出てしまう
    path=${url%/}
    path=${path%.git}
    path=${path%/}
    case $path in
      *://*)
        path=${path#*://}
        path=${path#*/}
        ;;
      [!/]*:*)
        # scp 形式（[user@]host:path）。ローカルパスは / か . で始まるのでここに来ない
        case ${path%%:*} in
          */*) ;;
          *) path=${path#*:} ;;
        esac
        ;;
    esac
    # owner/repo。パスが 1 階層なら repo だけ。ローカルパスや Azure Repos（org/project/_git/repo）は
    # 最後の 2 つになるが、同じ URL からは同じ値が出るので行の照合には足りる
    repo=$(printf '%s\n' "$path" | awk -F/ '{ if (NF >= 2) print $(NF-1) "/" $NF; else print $NF }')
  fi

  # ブランチを切らない作業（デフォルトブランチ・detached HEAD・メインの作業ツリー）は空にする。
  # 行はセッション ID で探すことになる
  branch=$(git symbolic-ref -q --short HEAD 2>/dev/null)
  default=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)
  if [ -n "$default" ] && [ "$branch" = "${default#origin/}" ]; then
    branch=
  fi
  # --path-format=absolute が無いと、サブディレクトリでは片方だけ相対パスで返り、
  # メインの作業ツリーでも一致しなくなる
  dirs=$(git rev-parse --path-format=absolute --git-dir --git-common-dir 2>/dev/null)
  if [ "$(printf '%s\n' "$dirs" | sed -n 1p)" = "$(printf '%s\n' "$dirs" | sed -n 2p)" ]; then
    branch=
  fi

  head=$(git rev-parse -q --verify HEAD 2>/dev/null)
  # どのリモートブランチにも含まれていないコミット。一度も push していないブランチでも同じ式で数えられる
  count=$(git rev-list --count HEAD --not --remotes 2>/dev/null) || count=0
  if [ "$count" -gt 0 ]; then
    subject=$(git log -1 --format=%s 2>/dev/null)
  fi
fi
host=$(hostname -s 2>/dev/null || uname -n)
now=$(TZ=Asia/Tokyo date +%Y-%m-%dT%H:%M:%S)
fingerprint=$(printf '%s\t%s\t%s' "$branch" "$head" "$count")

# field <名前> <値>: 値が空の項目も行は出す（行末に空白は残さない）
field() {
  if [ -n "$2" ]; then
    printf -- '- %s: %s\n' "$1" "$2"
  else
    printf -- '- %s:\n' "$1"
  fi
}

fields=$(
  field 'シート' "$sheet"
  field 'セッション ID' "$session_id"
  field 'リポジトリ' "$repo"
  field 'ブランチ' "$branch"
  field '未 push 件数' "$count"
  field '最新コミット件名' "$subject"
  field 'マシン' "$host"
  field '現在時刻（日本時間）' "$now"
)

# --- 間引き ---
mkdir -p "$state_dir" 2>/dev/null
find "$state_dir" -type f -mtime +7 -exec rm -f {} + 2>/dev/null
state="$state_dir/$session_id"

if [ "${1:-}" = --collect ]; then
  printf '%s\n' "$fingerprint" > "$state" 2>/dev/null
  printf '%s\n' "$fields"
  exit 0
fi

if [ -f "$state" ] && [ "$(cat "$state")" = "$fingerprint" ] \
  && [ -n "$(find "$state" -mmin -30 2>/dev/null)" ]; then
  exit 0
fi
printf '%s\n' "$fingerprint" > "$state" 2>/dev/null

message="作業状況のシートへの記録が要る。agent-status スキルの手順で、次の値を使って記録してからターンを終える。記録できない事情（コネクタに繋がらないなど）があれば、記録せずにその旨を一言報告して終える。
${fields}"

jq -n --arg message "$message" \
  '{hookSpecificOutput: {hookEventName: "Stop", additionalContext: $message}}'
exit 0
