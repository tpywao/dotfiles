#!/usr/bin/env bash
# PR を出していない自分のブランチと、止まっている自分の PR を GitHub から洗い出す。
#
#   stale-work-check [--notify]
#
# コミットは必ず push する運用が前提。手元にしか無いコミットや未コミットの変更は見えない。
#
# 設定ファイル: ${XDG_CONFIG_HOME:-~/.config}/stale-work-check/config
# 1 行に 1 つ指定する。# 以降はコメント。
#
#   repo <owner>/<name>      調べるリポジトリ。複数書ける
#   skip <glob>              PR を出さないブランチ（release/* など）。デフォルトブランチは書かなくても対象外
#   branch-days <日数>       最後のコミットがこれより古いブランチは放置済みとみなして出さない（既定 30）
#   stale-days <日数>        これより長く更新されていないオープン PR を止まっているとみなす（既定 7）
#
# 「自分のブランチ」は最後のコミットの作者が自分のもの。PR の検索は repo の owner に絞る。
#
# 結果は標準出力と ${XDG_STATE_HOME:-~/.local/state}/stale-work-check/latest.log に書く。
# --notify を付けると、見つかった件数を macOS の通知で知らせる。
#
# macOS 標準の bash 3.2 でも動くように書いている（テストを /bin/bash で流すため）。

set -euo pipefail

notify=false
case ${1:-} in
  --notify) notify=true ;;
  "") ;;
  *)
    echo "usage: stale-work-check [--notify]" >&2
    exit 2
    ;;
esac

config=${STALE_WORK_CHECK_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/stale-work-check/config}
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/stale-work-check

if [ ! -f "$config" ]; then
  echo "設定ファイルがありません: $config" >&2
  exit 1
fi

repos=()
skips=()
branch_days=30
stale_days=7

owners=()
branch_items=()
draft_items=()
stale_items=()
errors=()

while IFS= read -r line || [ -n "$line" ]; do
  line=${line%%#*}
  read -r key value <<<"$line" || true
  case ${key:-} in
    "") ;;
    repo) repos+=("$value") ;;
    skip) skips+=("$value") ;;
    branch-days) branch_days=$value ;;
    stale-days) stale_days=$value ;;
    *) echo "設定の不明なキーを無視します: $key" >&2 ;;
  esac
done <"$config"

if [ ${#repos[@]} -eq 0 ]; then
  echo "設定に repo がありません: $config" >&2
  exit 1
fi

is_skipped() {
  local p
  for p in ${skips[@]+"${skips[@]}"}; do
    # shellcheck disable=SC2254 # 設定の値を glob として照合する
    case $1 in $p) return 0 ;; esac
  done
  return 1
}

# shellcheck disable=SC2016 # $owner などは GraphQL の変数で、シェルでは展開しない
branches_query='query($owner: String!, $name: String!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    defaultBranchRef { name }
    refs(refPrefix: "refs/heads/", first: 100, after: $endCursor) {
      pageInfo { hasNextPage endCursor }
      nodes {
        name
        associatedPullRequests { totalCount }
        target { ... on Commit { committedDate author { user { login } } } }
      }
    }
  }
}'

check_branches() {
  local repo=$1 json default name date
  if ! json=$(gh api graphql --paginate -f query="$branches_query" \
    -f owner="${repo%%/*}" -f name="${repo#*/}"); then
    errors+=("$repo: ブランチを取得できませんでした")
    return 0
  fi

  # --paginate はページごとの JSON を連結して返す
  default=$(jq -rn 'first(inputs | .data.repository.defaultBranchRef.name) // ""' <<<"$json")

  while IFS=$'\t' read -r name date; do
    if [ "$name" = "$default" ] || is_skipped "$name"; then
      continue
    fi
    branch_items+=("$repo $name (最終コミット $date)")
  done < <(jq -r --arg me "$me" --argjson days "$branch_days" '
    (now - $days * 86400) as $since
    | .data.repository.refs.nodes[]
    | select(.target.author.user.login == $me)
    | select(.associatedPullRequests.totalCount == 0)
    | select((.target.committedDate | fromdateiso8601) >= $since)
    | "\(.name)\t\(.target.committedDate[:10])"' <<<"$json")
}

check_prs() {
  local o json args=() line
  for o in $(printf '%s\n' "${owners[@]}" | sort -u); do
    args+=(--owner "$o")
  done

  if ! json=$(gh search prs --author @me --state open "${args[@]}" --limit 100 \
    --json repository,number,title,isDraft,updatedAt); then
    errors+=("自分の PR を検索できませんでした")
    return 0
  fi

  while IFS= read -r line; do
    draft_items+=("$line")
  done < <(jq -r '.[] | select(.isDraft)
    | "\(.repository.nameWithOwner)#\(.number) (\(.updatedAt[:10]) 更新) \(.title)"' <<<"$json")

  while IFS= read -r line; do
    stale_items+=("$line")
  done < <(jq -r --argjson days "$stale_days" '(now - $days * 86400) as $cutoff
    | .[] | select((.isDraft | not) and ((.updatedAt | fromdateiso8601) < $cutoff))
    | "\(.repository.nameWithOwner)#\(.number) (\(.updatedAt[:10]) 更新) \(.title)"' <<<"$json")
}

section() {
  local title=$1
  shift
  if [ $# -gt 0 ]; then
    printf '\n## %s\n' "$title"
    printf -- '- %s\n' "$@"
  fi
}

report() {
  printf '# stale-work-check %s\n' "$(date '+%Y-%m-%d %H:%M')"
  section "PR の無いブランチ（${branch_days} 日以内にコミット）" ${branch_items[@]+"${branch_items[@]}"}
  section "draft の PR" ${draft_items[@]+"${draft_items[@]}"}
  section "${stale_days} 日以上更新のない PR" ${stale_items[@]+"${stale_items[@]}"}
  section "確認できなかったもの" ${errors[@]+"${errors[@]}"}
  if [ "$total" -eq 0 ] && [ ${#errors[@]} -eq 0 ]; then
    printf '\n該当なし\n'
  fi
}

if me=$(gh api user | jq -r .login); then
  for repo in "${repos[@]}"; do
    owners+=("${repo%%/*}")
    check_branches "$repo"
  done
  check_prs
else
  errors+=("gh の認証を確認できませんでした（gh auth status）")
fi

total=$((${#branch_items[@]} + ${#draft_items[@]} + ${#stale_items[@]}))

mkdir -p "$state_dir"
report | tee "$state_dir/latest.log"

if $notify && { [ "$total" -gt 0 ] || [ ${#errors[@]} -gt 0 ]; }; then
  message="ブランチ ${#branch_items[@]} 件・draft ${#draft_items[@]} 件・停止 ${#stale_items[@]} 件"
  if [ ${#errors[@]} -gt 0 ]; then
    message="${message}・確認失敗 ${#errors[@]} 件"
  fi
  osascript -e "display notification \"$message\" with title \"stale-work-check\" subtitle \"$state_dir/latest.log\"" || true
fi
