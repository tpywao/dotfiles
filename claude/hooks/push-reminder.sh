#!/bin/sh
# Stop hook: 未 push のコミットを残したままターンを終えようとしたら、push を促して続けさせる。
#
# 対象は cwd のリポジトリの、いまのブランチだけ。origin の無いリポジトリ、detached HEAD、
# origin のデフォルトブランチは対象外。git が動かない場所（コンテナの中で作った worktree など）
# でも黙って通す。
#
# 促すのは 1 回だけ。続けた結果のターン終わり（stop_hook_active が true）では止めない。
# push できない事情があっても、ターンを終えられなくなることはない。
set -u

input=$(cat)

if [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = true ]; then
  exit 0
fi

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
if [ -z "$cwd" ] || ! cd "$cwd" 2>/dev/null; then
  exit 0
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
git remote get-url origin >/dev/null 2>&1 || exit 0
branch=$(git symbolic-ref -q --short HEAD) || exit 0

default=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)
if [ -n "$default" ] && [ "$branch" = "${default#origin/}" ]; then
  exit 0
fi

# どのリモートブランチにも含まれていないコミット。未 push のブランチでも、一度も push して
# いないブランチでも同じ式で数えられる
count=$(git rev-list --count HEAD --not --remotes=origin 2>/dev/null) || exit 0
[ "$count" -gt 0 ] || exit 0

message="ブランチ $branch に未 push のコミットが $count 件ある。コミットしたら push する規則なので、push してからターンを終える。オープンな PR があるブランチでも通常の push でよい（force push はしない）。push できない事情（ユーザーが止めている、直接コミット禁止のブランチ、認証エラーなど）があるなら、push せずにその旨を一言報告して終える。"

jq -n --arg message "$message" \
  '{hookSpecificOutput: {hookEventName: "Stop", additionalContext: $message}}'
