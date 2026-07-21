---
name: daily-recap
description: Use when 「今日何してた？」「昨日の作業まとめて」など、特定日の作業内容の要約を求められたとき。引数で日付（YYYY-MM-DD）を指定可能。省略時は今日。
---

# daily-recap — 1日の作業サマリ

## 概要

git ログ・Claude Code セッション履歴・ccusage・Slack 送信ログの4情報源から、指定日に何をしていたかをプロジェクト別にまとめる。

対象日を `DATE`（YYYY-MM-DD）とする。省略時は今日。

## 手順

### 1. 情報源を並列で収集

```bash
# dotfiles の当日コミット
git -C ~/.dotfiles log --since="$DATE 00:00" --until="$DATE 23:59" \
  --pretty=format:'%h %ad %s' --date=format:'%H:%M'

# 当日アクティブだったプロジェクトの当たりを付ける
ls -lt ~/.claude/projects/ | head -20

# トークン使用量（対象日の行を読む。--until は使わない）
ccusage daily --since $DATE
```

### 2. 当日のセッションログを列挙

ディレクトリの mtime は当てにならない（当日 mtime でも中の jsonl が古いことがある）。**find -newermt を正とする**。

```bash
find ~/.claude/projects -name '*.jsonl' -newermt "$DATE 00:00" -not -path '*agent*'
```

過去日の場合は翌日 0 時で上限を切る: `! -newermt "<翌日> 00:00"`

### 3. 各セッションの冒頭ユーザーメッセージを抽出

```bash
jq -r 'select(.type=="user") | .message.content |
  if type=="string" then .
  elif type=="array" then (map(select(.type=="text") | .text) | join(" "))
  else empty end' "$f" \
  | grep -v '^\s*$' \
  | grep -v 'command-message\|command-name\|command-args\|system-reminder\|Caveat\|tool_result' \
  | head -3 | cut -c1-200
```

`/clear` や `/model` で始まるセッションは 2〜3 件目のメッセージまで読んで内容を特定する。

### 4. 活動のあったリポジトリの git ログを確認

プロジェクトディレクトリ名からリポジトリパスを復元する（`-Users-<user>-dev-myrepo` → `~/dev/myrepo` のように、先頭の `-Users-<user>-` をホームディレクトリに読み替え、残りの `-` をパス区切りとして解釈する）。

```bash
git -C <repo> log --all --since="$DATE 00:00" --until="$DATE 23:59" \
  --pretty=format:'%h %ad %d %s' --date=format:'%H:%M'
```

- `--all` でブランチ横断（feature ブランチの作業を拾う）
- `-workspaces-*` プロジェクトは devcontainer 内パスなのでホストから git 参照不可。セッションログのみで判断する

### 5. Slack の送信ログを取得（Slack MCP 接続時のみ）

`slack_search_public_and_private` ツールで自分の送信メッセージを検索する。自分の user_id はツールの説明文に記載されている（"Current logged in user's user_id is ..."）。

```
query: from:<@<自分のuser_id>> on:<DATE>
sort: timestamp / sort_dir: asc / include_context: false / response_format: concise
```

- 対象は public / private / DM / グループ DM のすべて（`channel_types` のデフォルト）
- Slack MCP が未接続のセッションではこの手順をスキップし、他の情報源のみでまとめる

## 出力形式

- **プロジェクト別にグルーピング**し、時間帯順に並べる
- コミットは時刻・チケット ID 付きで列挙。相談・調査系セッションはコミットと区別して書く
- Slack の送信メッセージは時刻・チャンネル付きの表で別セクションにまとめる
- 最後に ccusage の当日合計（トークン数・コスト）を1行添える

## 注意

- JSON 処理は jq を使う（python ワンライナー禁止）
- サブエージェントは使わずインラインの Bash で収集する（読み取りのみで軽い）
