---
name: claude-add-config
description: Use when ~/.claude/ に新しい skill・hook・agent・設定ファイルを追加するとき、または ~/.claude/ と ~/.dotfiles/claude/ の hardlink が切れている・反映されていないことに気づいたとき。
---

# Claude 設定ファイルの追加と dotfiles 同期

## 概要

~/.claude/ 配下の永続設定（skills, hooks, agents, CLAUDE.md, keybindings.json 等）は ~/.dotfiles/claude/ と **hardlink** で二重管理されている。relink フック（PostToolUse）は「両側に存在するファイル」の再リンク専用で、**新規ファイルは対象外**。手動での ln とコミットが必須。

## 手順（新規追加）

dotfiles リポジトリのフロー（origin/main から worktree を切って PR。main へ直接コミットしない）に従う。

1. `cd ~/.dotfiles && git fetch origin` し、`origin/main` から新規ブランチ + worktree を作成
2. worktree 側に `claude/<path>` としてファイルを作成し、コミット → push → PR を作成
3. すぐ有効化したい場合は worktree のファイルを `~/.claude/<path>` へコピー（main に実体が無い間は hardlink を張れないため暫定コピー。dotfiles 側が source of truth）
4. PR マージ後、main を pull して hardlink 化: `rm ~/.claude/<path> && ln ~/.dotfiles/claude/<path> ~/.claude/<path>`（暫定コピーと main の内容が一致していれば relink フックでも再リンクされる）
5. 検証: `ls -li ~/.dotfiles/claude/<path> ~/.claude/<path>` — inode 一致・リンク数 2 を確認

## 修復（リンク切れ）

症状: `ls -li` で両側の inode が不一致。Edit の atomic save（tmpfile + rename）や手動コピーで発生する。

1. `diff` で両側の内容一致を確認。異なる場合は新しい方を残す
2. `rm ~/.claude/<path> && ln ~/.dotfiles/claude/<path> ~/.claude/<path>`

注意: `./install.sh` の再実行では直らない（リンク先が存在するとスキップする仕様）。

## リンク切れの一括検出

```bash
find ~/.dotfiles/claude -type f -links 1 -not -name '*.local.*'
```

link count が 1 のファイルは ~/.claude/ 側と繋がっていない。

## よくある間違い

- `cp` や `ln -s` を使う → relink フックは hardlink 前提。必ず `ln`（symlink 不可）
- ~/.claude/ 側だけに作成して dotfiles 反映を忘れる → 他マシンへの同期から漏れる
- セッション状態（history.jsonl, projects/, backups/, plans/, shell-snapshots/ 等）まで dotfiles に入れる → 対象外。永続設定のみ管理する
