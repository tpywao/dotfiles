---
name: claude-env-audit
description: Use when Claude Code 環境の定期監査・健全性チェックをしたいとき。設定が壊れている気がする、許可プロンプトが増えた、放置ファイルが溜まっている気がするときにも使う。
---

# Claude Code 環境監査

## 概要

~/.claude/ と ~/.dotfiles/claude/ の健全性を**読み取り専用**でチェックし、問題を報告する。修正はユーザーの承認を得てから行う。

## チェックリスト

1. **settings.json の構文とモデル指定**: `jq . ~/.claude/settings.json` で構文確認。`model` 値が正規のモデル指定か確認。**注意**: `[1m]` サフィックス（例: `"claude-fable-5[1m]"`）は 1M コンテキストを指定する**正規の構文**であり破損ではない（過去に `[1m]` をエスケープ混入と誤診して「修正」した事例あり — 確証なく書き換えない）
2. **settings.json のキー差分精査**: `settings.json` はリンクせずマージ方式で反映するため（詳細は `claude/README.md`）、dotfiles 側に無いキーは反映されないまま手元に留まる。共有すべき設定が埋もれていないか確認する

    ```bash
    jq -s '
      .[0] as $live | .[1] as $shared |
      {
        live_only: [$live | keys[] as $k | select($shared | has($k) | not) | $k],
        differs:   [$live | keys[] as $k | select(($shared | has($k)) and ($live[$k] != $shared[$k])) | $k]
      }
    ' ~/.claude/settings.json ~/.dotfiles/claude/settings.json
    ```

    - `live_only`: グローバルにだけあるキー。マシンをまたいで揃えたいものは dotfiles へ入れる。ただし `autoMode` は Claude Code が生成し、ホームディレクトリのパスやリポジトリ名を含むため**入れない**
    - `differs`: 値が違うキー。`install.sh` の実行で dotfiles 側の値に戻る。`/model` や `/config` で変えた値を恒久化したいなら dotfiles 側を更新する
3. **permissions 棚卸し**: allow リストに危険なエントリ（書き込み系・破壊系）が紛れていないかのみ確認。利用パターンとの照合・再生成は /fewer-permission-prompts skill に委ねる
    - allow は**プレフィックス一致**なので、読み取り目的で置いたエントリでも破壊的なフラグを弾けない。`Bash(find *)` は `-delete` / `-exec` を、`Bash(rg *)` は `--pre=<cmd>` を、`Bash(git log *)` 等は `--output=<file>` を通す
    - auto mode では narrow な allow ルールが classifier を通らずに解決されるため、この経路は classifier のチェックも受けない。`deny` / `ask` が空なら歯止めが無いことを報告する
    - フラグ単位で止めたいものは `hooks/block-dangerous.sh` に足す（allow の利便性を保ったまま危険な形だけ弾ける）
4. **symlink 整合性**: `~/.claude/` 側が dotfiles を指す symlink になっているか確認する（`settings.json` は上記 2 で見るので対象外）

    ```bash
    find ~/.dotfiles/claude -type f -not -name 'settings.json' -not -name '*.relinkbak.*' -not -name '*.presymlink.*' -not -name '*.local.*' | while read -r src; do
      dst="$HOME/.claude/${src#$HOME/.dotfiles/claude/}"
      if [ ! -e "$dst" ]; then
        echo "MISSING       $dst"
      elif [ ! -L "$dst" ]; then
        echo "NOT A SYMLINK $dst"
      fi
    done
    ```

    `NOT A SYMLINK` は hardlink 時代の残りか手動コピー。`diff` で内容を比べ、`~/.claude/` 側にしかない編集があれば dotfiles 側へ取り込んでから `./install.sh` を実行する（内容が分岐していれば `*.presymlink.<ts>` へ退避される）。手順は claude-add-config skill に従う
    - `~/.claude/` 側にしかないファイルは `diff -rq ~/.dotfiles/claude/<dir> ~/.claude/<dir>`（対象: skills, hooks, agents）で検出する。dotfiles に入れるべきものか、そのマシン限定のものかを判断する
    - 退避ファイル（`*.presymlink.*` / `*.relinkbak.*`）は `~/.claude/` と `~/.dotfiles/claude/` の**両方**に残る。片側だけ見ると取りこぼす

        ```bash
        find ~/.claude ~/.dotfiles/claude \( -name '*.presymlink.*' -o -name '*.relinkbak.*' \) 2>/dev/null
        ```

        処分前に現行ファイルと比べ、退避側にしかない編集がないことを確認する。git 管理外なので削除すると復元できない
5. **memory 鮮度**: 監査対象プロジェクト（通常 -Users-ogiso--dotfiles）の MEMORY.md と memory/*.md を確認し、古くなった・誤っていた記憶の更新・削除候補を報告。全プロジェクトの memory は指示があった場合のみ
6. **skills の description**: 各 SKILL.md の description に発火条件（いつ使うか）が書かれているか
7. **dotfiles 同期**: `git -C ~/.dotfiles status --short --branch` で untracked / ahead を確認（コミット漏れ・push 忘れ）。あわせて `git branch -vv` で `[gone]`（リモート削除済み）のブランチを削除候補として報告する

## 出力形式

チェック項目ごとに 正常 / 要対応 を判定し、要対応には具体的な修正コマンドを添えて報告する。

## 頻度

2〜3 ヶ月に 1 回、または挙動の異常（プロンプト増加、設定が効かない等）を感じたとき。
