---
name: claude-env-audit
description: Use when Claude Code 環境の定期監査・健全性チェックをしたいとき。設定が壊れている気がする、許可プロンプトが増えた、放置ファイルが溜まっている気がするときにも使う。
---

# Claude Code 環境監査

## 概要

~/.claude/ と ~/.dotfiles/claude/ の健全性を**読み取り専用**でチェックし、問題を報告する。修正はユーザーの承認を得てから行う。

## チェックリスト

1. **settings.json**: `jq . ~/.claude/settings.json` で構文確認。`model` 値が正規のモデル指定か確認。**注意**: `[1m]` サフィックス（例: `"claude-fable-5[1m]"`）は 1M コンテキストを指定する**正規の構文**であり破損ではない。/model コマンドで保存された live 側の値が正（過去に `[1m]` をエスケープ混入と誤診して「修正」した事例あり — 確証なく書き換えない）
2. **permissions 棚卸し**: allow リストに危険なエントリ（書き込み系・破壊系）が紛れていないかのみ確認。利用パターンとの照合・再生成は /fewer-permission-prompts skill に委ねる
3. **hardlink 整合性**: `find ~/.dotfiles/claude -type f -links 1 -not -name '*.local.*'` でリンク切れ検出。片側にしかないファイルは管理対象ディレクトリごとに `diff -rq ~/.dotfiles/claude/<dir> ~/.claude/<dir>`（対象: skills, hooks, agents。加えて CLAUDE.md, keybindings.json）で検出。修復は claude-add-config skill の手順に従うが、**内容が乖離している場合はどちらが正か（更新日時・変更経緯）を確認してから**リンクし直す
4. **backups/ 確認**: ~/.claude/backups/ の古いバックアップ（`.claude.json.backup.*` や移行時の zip 等）を一覧し、直近数個を残した削除候補を報告
5. **plans/ 確認**: ~/.claude/plans/ を日付順に一覧提示。完了メタデータは存在せず読み取りでは完了判定できないため、削除はユーザー判断に委ねる
6. **memory 鮮度**: 監査対象プロジェクト（通常 -Users-ogiso--dotfiles）の MEMORY.md と memory/*.md を確認し、古くなった・誤っていた記憶の更新・削除候補を報告。全プロジェクトの memory は指示があった場合のみ
7. **skills の description**: 各 SKILL.md の description に発火条件（いつ使うか）が書かれているか
8. **dotfiles 同期**: `git -C ~/.dotfiles status --short --branch` で untracked / ahead を確認（コミット漏れ・push 忘れ）

## 出力形式

チェック項目ごとに 正常 / 要対応 を判定し、要対応には具体的な修正コマンドを添えて報告する。

## 頻度

2〜3 ヶ月に 1 回、または挙動の異常（プロンプト増加、設定が効かない等）を感じたとき。
