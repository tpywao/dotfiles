# Dotfiles Repository Context

このドキュメントは、ユーザーの dotfiles（~/.dotfiles）リポジトリの作業ガイドです。

## プロジェクト概要
- **用途**: macOS + Linux 向けの個人用 dotfiles リポジトリ
- **管理対象**: zsh, git, nix, Brewfile, karabiner, fzf など
- **主な構成**:
  - `zsh/`: zsh 設定（$ZDOTDIR 配下）
  - `git/`: git 設定（gitconfig, gitignore）
  - `nix/`: Nix/NixOS 設定（flake.nix, flake.lock）
  - `Brewfile`: macOS Homebrew パッケージリスト
  - `karabiner/`: Karabiner-Elements 設定（キーボード）
  - `fzf/`: fzf 設定ファイル
  - `claude/`: Claude Code 関連設定（hooks, skills など）

## 作業時の注意事項

### 固有文言の禁止
- このリポジトリに追加するファイル（skills, hooks, 設定, ドキュメント等）には、**マシン・個人・勤務先プロジェクトに固有の文言を書かない**
  - 対象: ユーザー名、ホスト名、勤務先の社名・プロジェクト名・リポジトリ名、社内 URL など
  - 例示が必要な場合はプレースホルダや汎用名を使う（`<user>`, `~/dev/myrepo` など）。ホームディレクトリは `~` / `$HOME` で表記する
- 理由: このリポジトリは複数マシンで共用し、公開しても支障ない状態を保つため

### 重要: zsh 設定
- **重要**: ~/.zshrc は読まれません。$ZDOTDIR 配下（.dotfiles/zsh/）の設定を編集してください
- 設定値: $ZDOTDIR=~/.dotfiles/zsh, no_global_rcs
- zsh 設定ファイル: `zsh/.zshrc`, `zsh/.zprofile`, `zsh/.zlogout`

### Nix/Flake 管理
- `flake.nix`: Nix パッケージと home-manager の定義
- `flake.lock`: Nix flake の依存関係ロック（自動生成）
  - **編集禁止**: 手書き編集しないでください
  - 更新方法: `nix flake update` コマンド
- `nix flake check --impure` で構文確認可
  - `--impure` 必須: `nix/home.nix` が `builtins.getEnv "USER"` でユーザー名を取得しているため、pure 評価では `Username could not be determined` で失敗する
  - `flake check` だけでなく `nix build` / `home-manager switch --flake .#${DOTFILES_MACHINE:-work-mac} --impure` など評価を伴うコマンドすべてに `--impure` が要る
- **マシンごとの構成**: `homeConfigurations` はマシンごとにエントリを持ち（例: `work-mac`）、共通の `home.nix` ＋マシン固有モジュール（例: `work-mac.nix`、`common.nix` を imports）を組み合わせる。適用先は環境変数 `DOTFILES_MACHINE`（未設定時 `work-mac`）で選択し、dotfiles 管理外の `~/.local/zsh/*.zsh` で export する。マシン追加手順は `nix/README.md` を参照
  - `home.packages` はリスト型オプションで、複数モジュールの定義は自動的に concat（マージ）される（後勝ち上書きではない）。マシン固有パッケージは `work-mac.nix` に追加分だけ列挙する（`packages.nix` を再 import すると二重登録になる）
  - 共通パッケージは `nix/packages.nix`、マシン固有は `nix/work-mac.nix` に書く

### Brewfile 管理
- `Brewfile`: macOS Homebrew パッケージリスト
- `Brewfile.gui`: GUI アプリケーションリスト
- 更新方法:
  - `brew bundle dump --file=Brewfile` で現在のパッケージをダンプ
  - 手動編集後、`brew bundle install` でインストール

### git 設定
- `git/gitconfig`: グローバル git 設定
- `git/gitignore`: グローバル gitignore
- ローカル git 設定（.gitconfig.local）と結合される
- **編集時の確認**: `git config --list` で反映を確認

### Claude Code 設定
- `claude/`: Claude Code 関連（hooks, skills など）
- グローバル ~/.claude/ との hardlink で同期
- Edit/Write 後に自動で hardlink が再同期される

### AI ツール環境（ai-tools）
- **ディレクトリ**: `ai-tools/`（dotfiles で管理）
- **シンボリックリンク**: `~/.local/ai-tools` → `~/.dotfiles/ai-tools`
- **flake.nix**: Node.js + 3つの開発ツール（ccusage, repomix, codegraph）を定義
- **常設**: ai-tools は home-manager に統合済み。`home-manager switch` すると codegraph/ccusage/repomix が `~/.nix-profile/bin` に入り**常に PATH 上**にある（`cd ~/.local/ai-tools` や `nix develop` は不要）
- **パッケージング方式**: `ai-tools/flake.nix` は `buildNpmPackage` + `package-lock.json` で 3 ツールを単一 derivation として提供（lockfile ベースの固定・オフラインビルド。#15/#20 でサプライチェーン対策として npx 方式から移行）
  - 依存取得は `fetchNpmDeps`（fixed-output derivation）による hash 検証つき。推移的依存まで lockfile で固定され、実行時にレジストリへアクセスしない
  - `npmFlags = [ "--ignore-scripts" ]`: install スクリプト（npm マルウェアの主要経路）は実行しない。外さないこと
  - **`runCommand`+`npm install` に戻さないこと**: Nix ビルドサンドボックスはネットワーク不可で、空の derivation を「成功」として生成してしまう（失敗が握りつぶされる）。`fetchNpmDeps` は fixed-output derivation なのでネットワーク可
  - **ツールの更新手順**: `ai-tools/package.json` のバージョンを上げ → `cd ai-tools && npm install --ignore-scripts` で lockfile を再生成 → `flake.nix` の `npmDepsHash` を再計算（いったん `lib.fakeHash` にして `nix build` し、hash mismatch エラーの `got:` の値を転記）。`npmDepsFetcherVersion` を変えた場合も hash の再計算が必要
- **使用方法**: 下記「AI ツール（ccusage, repomix, codegraph）」セクションを参照

## AI ツール（ccusage, repomix, codegraph）

このリポジトリでは 3 つの AI 関連ツールを Nix flake で一元管理しています。

### セットアップ

home-manager に統合済みのため、通常は追加セットアップ不要。`home-manager switch --flake .#${DOTFILES_MACHINE:-work-mac} --impure` で 3 ツールが `~/.nix-profile/bin` に入り、以降どのシェルでもそのまま使える。

（`ai-tools/flake.nix` には dev shell も残っているが、ツールを使うだけなら `cd` や `nix develop` は不要）

### 各ツールの使用方法

#### 1. ccusage — Claude Code トークン使用量・コスト分析

Claude Code の利用状況・トークン消費量・コストを追跡。

```bash
ccusage daily          # 日単位の使用量表示
ccusage weekly         # 週単位の集計
ccusage monthly        # 月単位の集計
ccusage daily --since 2026-05-01      # 特定日以降を表示
ccusage daily --json > usage.json      # JSON でエクスポート
ccusage claude monthly                 # Claude のみ抽出
```

#### 2. repomix — リポジトリを AI 向けに 1 ファイル化

大規模リポジトリを XML/Markdown に圧縮し、LLM に供給。

```bash
repomix                    # カレントディレクトリをリポジトリ化
repomix /path/to/repo      # 指定ディレクトリを処理
repomix --format markdown  # Markdown 形式で出力
repomix --exclude src/test # 特定ディレクトリを除外
```

出力: `repomix-output.xml`（デフォルト）→ Claude にコピペして大規模コード分析

#### 3. codegraph — ローカルコード知識グラフ構築

プロジェクトのコード知識グラフをローカルインデックス化し、Claude Code と連携。セマンティック検索で関連コードを素早く検索可能。

初回セットアップ（プロジェクトごと）：

```bash
codegraph install         # Claude Code 等のエージェントに MCP サーバーを統合
cd ~/my-project
codegraph init            # プロジェクトの .codegraph/ を初期化
```

日常的な使用：

```bash
# init 後は自動で Claude Code がグラフを活用
codegraph sync      # 差分同期（通常はこれ）
codegraph index     # フル再構築（コード大幅変更時。rebuild というサブコマンドは無い）
codegraph status    # インデックス状態の確認
```

効果: Claude Code が関数の呼び出し元検索などを可能に。トークン消費削減（全コード送信不要）

## よく使うコマンド
```bash
# Nix 環境の更新
nix flake update

# Nix 環境のチェック（--impure 必須: getEnv "USER" のため）
nix flake check --impure

# Brewfile の更新
brew bundle dump --file=Brewfile --force

# git 設定確認
git config --list --local
git config --global --list

# zsh 設定の再読み込み
exec zsh
```

## 保守性のルール
1. 自動生成ファイル（flake.lock など）は手書き編集しない
2. 設定変更後は実際に機能するか確認（exec zsh など）
3. 新しい dotfiles は install.sh に追加
4. git commit 時は `feat(component):` 形式で記述

## 参考資料
- [README.md](../README.md)
- ユーザーメモリ: zsh の $ZDOTDIR 設定
