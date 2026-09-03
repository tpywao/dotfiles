---
name: daily-recap
description: Use when 「今日何してた？」「昨日の作業まとめて」など、特定日の作業内容の要約を求められたとき。引数で日付（YYYY-MM-DD）を指定可能。省略時は今日。
---

# daily-recap — 1日の作業サマリ

## 概要

git ログ・Claude Code セッション履歴・ccusage・Slack 送信ログ・Obsidian Daily Notes・Google カレンダーの6情報源から、指定日に何をしていたかをプロジェクト別にまとめる。

対象日を `DATE`（YYYY-MM-DD）とする。省略時は今日。

## 手順

収集は5体のサブエージェント（Agent ツール）に委譲し、**1メッセージで並列起動**する。各エージェントは互いに独立で、他エージェントの出力に依存しない。プロンプトは以下のテンプレートに DATE 等を埋めて使う（テンプレートはユーザー承認済みのため、都度の事前提示は不要）。各プロンプトは日本語で書き、末尾に「回答・報告はすべて日本語で書くこと。技術用語やコード識別子は原文のままでよい。」を必ず含める。収集エージェントはすべて読み取り専用 — 書き込み・送信はさせない。

ccusage はエージェントに委譲せず、**親セッションが直接実行**する（出力が数行でエージェントを立てるコストに見合わないため）: `ccusage daily --since <DATEをYYYYMMDD化>` の出力から対象日の行だけを読む（`--until` は使わない）。

全エージェントの報告が揃ったら、親セッションが「出力形式」に従い統合する。

### Agent A1: Claude Code セッションログ

プロンプトに以下の指示・コマンドをそのまま埋め込む:

1. **当日のセッションログを列挙**。ディレクトリの mtime は当てにならない（当日 mtime でも中の jsonl が古いことがある）ため、fd の更新時刻フィルタを正とする。対象日が今日なら `--changed-before` は省略:

```bash
fd -e jsonl --changed-after "$DATE 00:00:00" --changed-before "<翌日> 00:00:00" \
  -E '*agent*' . ~/.claude/projects
```

2. **各セッションの冒頭ユーザーメッセージを抽出**（JSON 処理は jq を使う。python ワンライナー禁止）:

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

報告形式: セッション一覧（プロジェクト・冒頭メッセージ要約）。

### Agent A2: git ログ

対象リポジトリはセッションログに依存せず自己解決する（Agent A1 と独立に並列実行するため）。プロンプトに以下の指示・コマンドをそのまま埋め込む:

1. **dotfiles の当日コミット**

```bash
git -C "$DOTFILES" log --since="$DATE 00:00" --until="$DATE 23:59" \
  --pretty=format:'%h %ad %s' --date=format:'%H:%M'
```

2. **対象リポジトリの列挙**。`~/.claude/projects` 直下の全プロジェクトディレクトリ名（当日活動があったかは問わない）をリポジトリパスに復元する（`-Users-<user>-dev-myrepo` → `~/dev/myrepo` のように、先頭の `-Users-<user>-` をホームディレクトリに読み替え、残りの `-` をパス区切りとして解釈する）。

3. **各リポジトリの当日 git ログ**。日付フィルタ付きの `git log` は速く、活動のなかったリポジトリは空が返るだけなので、復元できた全リポジトリに対して実行してよい:

```bash
git -C <repo> log --all --since="$DATE 00:00" --until="$DATE 23:59" \
  --pretty=format:'%h|%an|%ad|%s' --date=format:'%H:%M'
```

- `--all` でブランチ横断（feature ブランチの作業を拾う）
- `-workspaces-*` プロジェクトは devcontainer 内パスなのでホストから git 参照不可。スキップし、親セッションが Agent A1 のセッションログで判断する
- gitdir がコンテナ内パスを指す worktree はホストから `git log` 参照不可。同じリポジトリのホスト側クローンがあればその `git log --all` で補完し、なければセッションログで判断する

報告形式: リポジトリ別コミット一覧（時刻・作者付き）。当日コミットのなかったリポジトリは省略。

### Agent B: Slack 送信ログ（Slack MCP 接続時のみ）

親セッションで Slack MCP ツールが利用可能な場合のみ起動する。未接続ならスキップし、他の情報源のみでまとめる。

プロンプトに埋め込む指示: `slack_search_public_and_private`（未ロードなら ToolSearch でロード）で自分の送信メッセージを検索する。自分の user_id はツールの説明文に記載されている（"Current logged in user's user_id is ..."）。

```
query: from:<@<自分のuser_id>> on:<DATE>
sort: timestamp / sort_dir: asc / include_context: false / response_format: concise
```

- 対象は public / private / DM / グループ DM のすべて（`channel_types` のデフォルト）

報告形式: 時刻・チャンネル・内容要約の一覧。

### Agent C: Obsidian Daily Note

プロンプトに埋め込む指示: vault パスは Obsidian の設定から動的に解決する（マシンごとに vault の場所・名前が異なるため、パスをハードコードしない）。デイリーノートのフォルダは vault 内の `.obsidian/daily-notes.json` の `folder`、ファイル名は `format` 未設定なら `YYYY-MM-DD.md`:

```bash
jq -r '.vaults[].path' ~/Library/"Application Support"/obsidian/obsidian.json | while read -r vault; do
  folder=$(jq -r '.folder // empty' "$vault/.obsidian/daily-notes.json" 2>/dev/null)
  f="$vault/${folder:+$folder/}$DATE.md"
  [ -f "$f" ] && echo "$f"
done
```

見つかったノートを Read で読み、出勤・退勤セクションの勤務時間と着手チケット、TODO・起きたことなどの手書きメモを報告する。

- ノートが存在しない日（休日など）や Obsidian 未導入のマシンでは「ノートなし」と報告する
- Linux では `~/.config/obsidian/obsidian.json` を参照する

### Agent D: Google カレンダー（Google Calendar MCP 接続時のみ）

親セッションで Google Calendar MCP ツールが利用可能な場合のみ起動する。未接続ならスキップし、他の情報源のみでまとめる。

プロンプトに埋め込む指示: `list_events`（未ロードなら ToolSearch でロード）で対象日の予定を取得する:

```
startTime: <DATE>T00:00:00 / endTime: <翌日>T00:00:00
```

- タイムゾーンなしの ISO 8601 で渡す（カレンダー自身のタイムゾーンで解釈される）
- `calendarId` は省略（primary カレンダー）。仕事用カレンダーが別にある場合のみ `list_calendars` で解決して追加取得する
- 辞退済みの予定は除外する

報告形式: 時刻・予定タイトルの一覧（終日予定は「終日」と明記）。予定がない日は「予定なし」と報告する。

## 出力形式

- **プロジェクト別にグルーピング**し、時間帯順に並べる
- コミットは時刻・チケット ID 付きで列挙。相談・調査系セッションはコミットと区別して書く
- Slack の送信メッセージは時刻・チャンネル付きの表で別セクションにまとめる
- カレンダーの予定（会議など）は時刻付きで一日の流れに織り込み、作業との対応が分かるようにする
- 最後に ccusage の当日合計（トークン数・コスト）を1行添える

## 注意

- JSON 処理は jq を使う（python ワンライナー禁止）— サブエージェントのプロンプトにも明記する
- ファイル列挙は find でなく fd を使う
