---
name: claude-add-config
description: Use when ~/.claude/ に新しい skill・hook・agent・設定ファイルを追加するとき、または ~/.claude/ 配下が ~/.dotfiles/claude/ への symlink になっていない・反映されていないことに気づいたとき。
---

# Claude 設定ファイルの追加と dotfiles 同期

## 概要

~/.claude/ 配下の永続設定（skills, hooks, agents, CLAUDE.md, keybindings.json 等）は ~/.dotfiles/claude/ への **symlink** で管理する。dotfiles 側が唯一の実体で、~/.claude/ 側は参照専用。

- 編集は必ず dotfiles 側で行う。Claude Code の Edit は symlink 経由の書き込みを拒否する（`Refusing to write through symlink`）
- **新規ファイルは `install.sh` を実行するまでリンクされない**。手動で張る場合も含め、下記の手順に従う
- `settings.json` だけは例外でリンクしない（Claude Code 自身が書き込むため）。`install.sh` の `merge_claude_settings` が共有キーのみを反映する。詳細は `claude/README.md`

## 手順（新規追加）

dotfiles リポジトリのフロー（origin/main から worktree を切って PR。main へ直接コミットしない）に従う。

1. `cd ~/.dotfiles && git fetch origin` し、`origin/main` から新規ブランチ + worktree を作成
2. worktree 側に `claude/<path>` としてファイルを作成し、コミット → push → PR を作成
3. すぐ有効化したい場合は worktree のファイルを `~/.claude/<path>` へコピー（worktree はマージ後に消えるので symlink を張らない。dotfiles 側が source of truth）
4. PR マージ後、main を pull して `./install.sh` を実行する（暫定コピーは内容が一致すればそのまま symlink へ置き換わる。分岐していれば `*.presymlink.<ts>` に退避される）
   - `install.sh` を通したくない場合は個別に張る: `/bin/rm ~/.claude/<path> && ln -s ~/.dotfiles/claude/<path> ~/.claude/<path>`
5. 検証: `ls -la ~/.claude/<path>` — dotfiles 側を指す symlink になっていることを確認

## 修復（リンクされていない）

症状: `~/.claude/<path>` が symlink ではなく実ファイルになっている。hardlink 時代の残り、手動コピー、`install.sh` 未実行のいずれか。

1. `diff ~/.dotfiles/claude/<path> ~/.claude/<path>` で内容を確認。~/.claude/ 側にしかない編集があれば dotfiles 側へ取り込む
2. `./install.sh` を実行する（内容が分岐していれば `*.presymlink.<ts>` へ退避してから張り替える）

## リンク状態の一括検出

```bash
find ~/.dotfiles/claude -type f -not -name 'settings.json' -not -name '*.relinkbak.*' | while read -r src; do
  dst="$HOME/.claude/${src#$HOME/.dotfiles/claude/}"
  if [ ! -e "$dst" ]; then
    echo "MISSING $dst"
  elif [ ! -L "$dst" ]; then
    echo "NOT A SYMLINK $dst"
  fi
done
```

## よくある間違い

- `~/.claude/` 側を編集しようとする → symlink なので Edit が拒否される。dotfiles 側を編集する
- `settings.json` にリンクを張る → Claude Code が書き込むマシン固有の値（`autoMode.environment` にホームのパスやリポジトリ名が入る）が dotfiles へ流入する。マージ方式のまま触らない
- ~/.claude/ 側だけに作成して dotfiles 反映を忘れる → 他マシンへの同期から漏れる
- セッション状態（history.jsonl, projects/, backups/, plans/, shell-snapshots/ 等）まで dotfiles に入れる → 対象外。永続設定のみ管理する
