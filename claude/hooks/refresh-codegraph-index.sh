#!/usr/bin/env bash
# codegraph 実行の直前に、対象リポジトリを最新化して codegraph インデックスを同期する PreToolUse hook。
# 更新できなかったときは exit 2 でブロックし、対処手順をメッセージで返す
# （古いインデックスのまま黙って進めない）。
set -euo pipefail

FETCH_MAX_AGE_MIN=15

# 発火判定: codegraph の MCP ツール呼び出しか、Bash での codegraph 実行か
input=$(cat)
tool_name=$(jq -r '.tool_name // empty' <<<"$input")

case "$tool_name" in
  mcp__codegraph__*)
    target=$(jq -r '.tool_input.projectPath // .cwd // empty' <<<"$input")
    ;;
  Bash)
    cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
    grep -qE '(^|[ /;|&(])codegraph ' <<<"$cmd" || exit 0
    target=$(jq -r '.cwd // empty' <<<"$input")
    ;;
  *)
    exit 0
    ;;
esac

# 対象は .codegraph/ を持つリポジトリのみ（インデックスを作ったこと自体を opt-in とみなす）
[ -n "$target" ] || exit 0
repo=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -d "$repo/.codegraph" ] || exit 0

# 鮮度は FETCH_HEAD の mtime で見る。専用マーカーを持たないので手動 git fetch の直後も
# ここでスキップされる。未 fetch でファイルが無い場合は確認に進む。
# --absolute-git-dir は worktree でも実体の gitdir を返す（--git-path は通常リポジトリで相対パス）
fetch_head="$(git -C "$repo" rev-parse --absolute-git-dir)/FETCH_HEAD"
[ -z "$(find "$fetch_head" -mmin -"$FETCH_MAX_AGE_MIN" 2>/dev/null)" ] || exit 0

# tracked ファイルに変更がある working tree は作業中とみなし pull しない。
# untracked のみは対象のまま（読み取り専用クローンにも untracked な生成物が置かれがち）
[ -z "$(git -C "$repo" status --porcelain --untracked-files=no 2>/dev/null)" ] || exit 0

# fetch できないとき（オフライン等）は判定材料がないので素通しする。
# 「通信不能」と「fast-forward 不可」を切り分けるため pull 一発にはまとめない
git -C "$repo" fetch --quiet >/dev/null 2>&1 || exit 0

behind=$(git -C "$repo" rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)
[ "$behind" -gt 0 ] || exit 0

# 最新化。pull と sync で必要な対処が違うため、失敗時のメッセージは分ける
if ! git -C "$repo" pull --ff-only --quiet >/dev/null 2>&1; then
  echo "codegraph-refresh: $repo はリモートより ${behind} コミット遅れているが git pull --ff-only に失敗した。手動で更新し codegraph sync を実行してから再試行すること。" >&2
  exit 2
fi

if ! (cd "$repo" && codegraph sync >/dev/null 2>&1); then
  echo "codegraph-refresh: $repo を ${behind} コミット分 pull したが codegraph sync に失敗した。cd $repo && codegraph index でインデックスを再構築してから再試行すること。" >&2
  exit 2
fi

echo "codegraph-refresh: $repo を ${behind} コミット分更新し、codegraph インデックスを同期した"
exit 0
