#! /bin/sh
# nix/stale-work-check.sh をケースごとに検証する。
#
#   sh tests/nix/stale-work-check_test.sh
#
# gh と osascript はスタブに差し替える。ネットワークへは出ず、実際の ~/.config や
# 通知も触らない。
#
# gh api graphql --paginate はページごとの JSON を連結して返す。スタブも 2 ページを
# 連結して返し、2 ページ目のブランチが報告に出ることでページをまたいで読めているかを
# 確かめる。

DOTFILES=$(cd "$(dirname "$0")/../.." && pwd -P)
SCRIPT="$DOTFILES/nix/stale-work-check.sh"

pass_count=0
fail_count=0

pass() {
  pass_count=$((pass_count + 1))
}

fail() {
  fail_count=$((fail_count + 1))
  printf 'FAIL  %s\n' "$1"
}

# assert_line <部分文字列> <期待する行の部分文字列> <実際の出力> <ラベル>
# 1 つ目を含む行が 2 つ目も含むかを確かめる
assert_line() {
  line=$(printf '%s\n' "$3" | grep -F -- "$1" | head -n 1)
  case "$line" in
    "") fail "$4: no line contains $1" ;;
    *"$2"*) pass ;;
    *) fail "$4: expected=$2 actual=$line" ;;
  esac
}

# assert_no_line <あってはいけない部分文字列> <実際の出力> <ラベル>
assert_no_line() {
  if printf '%s\n' "$2" | grep -F -q -- "$1"; then
    fail "$3: unexpected line with $1"
  else
    pass
  fi
}

T=$(mktemp -d)
trap 'rm -r "$T"' EXIT
STUB="$T/stub"
mkdir -p "$STUB" "$T/gh"

export HOME="$T/home"
export XDG_CONFIG_HOME="$T/config"
export XDG_STATE_HOME="$T/state"
mkdir -p "$HOME"

# gh api user / gh api graphql / gh search prs をファイルで差し替える。
# 引数は $T/gh/<種類>.args に残す
cat >"$STUB/gh" <<EOF
#! /bin/sh
case "\$1 \$2" in
  "api user") cat "$T/gh/user.json" ;;
  "api graphql")
    echo "\$@" >>"$T/gh/graphql.args"
    cat "$T/gh/graphql.json"
    ;;
  "search prs")
    echo "\$@" >"$T/gh/search.args"
    cat "$T/gh/search.json"
    ;;
  *) exit 1 ;;
esac
EOF
printf '#! /bin/sh\necho "$@" >"%s/osascript.args"\n' "$T" >"$STUB/osascript"
chmod +x "$STUB/gh" "$STUB/osascript"
export PATH="$STUB:$PATH"

now=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
old=2020-01-01T00:00:00Z

echo '{"login":"me"}' >"$T/gh/user.json"

# ref <ブランチ> <PR の数> <作者> <コミット日時>
ref() {
  printf '{"name":"%s","associatedPullRequests":{"totalCount":%s},"target":{"committedDate":"%s","author":{"user":{"login":"%s"}}}}' \
    "$1" "$2" "$4" "$3"
}

cat >"$T/gh/graphql.json" <<EOF
{"data":{"repository":{"defaultBranchRef":{"name":"main"},"refs":{"pageInfo":{"hasNextPage":true,"endCursor":"c1"},"nodes":[
  $(ref main 0 me "$now"),
  $(ref feat/nopr 0 me "$now"),
  $(ref feat/withpr 1 me "$now"),
  $(ref feat/other 0 someone "$now"),
  $(ref feat/old 0 me "$old"),
  $(ref release/x 0 me "$now")
]}}}}
{"data":{"repository":{"defaultBranchRef":{"name":"main"},"refs":{"pageInfo":{"hasNextPage":false,"endCursor":"c2"},"nodes":[
  $(ref feat/page2 0 me "$now")
]}}}}
EOF

cat >"$T/gh/search.json" <<EOF
[
  {"repository":{"nameWithOwner":"acme/app"},"number":10,"title":"draft one","isDraft":true,"updatedAt":"$now"},
  {"repository":{"nameWithOwner":"acme/app"},"number":11,"title":"old one","isDraft":false,"updatedAt":"$old"},
  {"repository":{"nameWithOwner":"acme/app"},"number":12,"title":"fresh one","isDraft":false,"updatedAt":"$now"}
]
EOF

mkdir -p "$XDG_CONFIG_HOME/stale-work-check"
cat >"$XDG_CONFIG_HOME/stale-work-check/config" <<EOF
# コメント行
repo acme/app
skip release/*
branch-days 30
stale-days 7
EOF

out=$(bash "$SCRIPT" 2>&1)
status=$?

[ "$status" -eq 0 ] && pass || fail "exit status: $status"

assert_line "feat/nopr" "acme/app feat/nopr (最終コミット " "$out" "PR の無い自分のブランチ"
assert_line "feat/page2" "acme/app feat/page2" "$out" "2 ページ目のブランチ"
assert_no_line "feat/withpr" "$out" "PR のあるブランチ"
assert_no_line "feat/other" "$out" "他人のブランチ"
assert_no_line "feat/old" "$out" "branch-days より古いブランチ"
assert_no_line "release/x" "$out" "skip の glob に当たるブランチ"
assert_no_line "acme/app main " "$out" "デフォルトブランチ"
assert_line "-f owner=" "-f owner=acme" "$(cat "$T/gh/graphql.args")" "ブランチの取得に owner を渡す"
assert_line "-f name=" "-f name=app" "$(cat "$T/gh/graphql.args")" "ブランチの取得に name を渡す"

assert_line "#10" "draft one" "$out" "draft の PR"
assert_line "#11" "old one" "$out" "更新が止まった PR"
assert_no_line "#12" "$out" "最近更新された PR"
assert_line "--owner" "--owner acme" "$(cat "$T/gh/search.args")" "PR の検索を owner に絞る"

[ -f "$XDG_STATE_HOME/stale-work-check/latest.log" ] && pass || fail "latest.log が書かれない"
[ -f "$T/osascript.args" ] && fail "--notify 無しで通知した" || pass

bash "$SCRIPT" --notify >/dev/null 2>&1
assert_line "display notification" "ブランチ 2 件・draft 1 件・停止 1 件" "$(cat "$T/osascript.args" 2>/dev/null)" "--notify の件数"

# gh が認証できなければ、確認できなかったものとして報告し通知する
rm "$T/osascript.args"
echo '{"message":"Requires authentication"}' >"$T/gh/user.json"
printf '#! /bin/sh\ncase "$1 $2" in "api user") exit 1 ;; *) exit 1 ;; esac\n' >"$STUB/gh"
out=$(bash "$SCRIPT" --notify 2>&1)
assert_line "gh の認証" "gh auth status" "$out" "gh が認証できない"
assert_line "display notification" "確認失敗 1 件" "$(cat "$T/osascript.args" 2>/dev/null)" "gh が認証できないときの通知"

# 設定ファイルが無ければ失敗で終わる
XDG_CONFIG_HOME="$T/none" bash "$SCRIPT" >/dev/null 2>&1
[ $? -eq 1 ] && pass || fail "設定ファイルが無いのに exit 1 にならない"

printf '%d passed, %d failed\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
