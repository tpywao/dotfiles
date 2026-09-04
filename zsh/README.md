# zsh

zsh の設定一式。`~/.zshenv` をこのディレクトリの `.zshenv` への symlink にし、その中で `$ZDOTDIR` をこのディレクトリに設定している。以降の設定ファイル（`.zshrc` など）はすべて `$ZDOTDIR` 配下から読まれるため、**`~/.zshrc` は読まれない**（`no_global_rcs` も設定済み）。

## 読み込みフロー

```
~/.zshenv (symlink)
└── .zshenv            環境変数・PATH（nix 優先）・no_global_rcs
    ├── load-log.zsh   読み込みログヘルパー（_load_begin/_load_end）
    ├── ../utils/utils.bash   is_mac / is_wsl / is_cmd_exists など
    └── mac.zsh または wsl.zsh   OS 判定で片方だけ

.zshrc（対話シェルのみ）
    ├── sheldon（プラグイン管理）、direnv
    ├── langs/rust.zsh   （ruby/python/go はコメントアウト中）
    ├── history・補完・prompt・vcs_info の設定
    ├── ../fzf/fzf.functions.zsh   fzf ウィジェットの関数定義
    ├── zoxide、gcloud
    ├── aliases.zsh → keybinds.zsh → check.zsh
    └── ~/.local/zsh/*.zsh   マシン固有設定（dotfiles 管理外）
```

## ファイル一覧

| ファイル | 役割 |
| --- | --- |
| `.zshenv` | 全シェル共通の入口。`$ZDOTDIR`・`$DOTFILES`・`$LOCAL_ROOT` の定義、PATH/fpath の構築（nix profile 優先）、OS 別設定の振り分け |
| `.zshrc` | 対話シェル用。setopt、history、補完、prompt、プラグイン・ツール初期化、他ファイルの source |
| `.gitignore` | zsh が生成するキャッシュ（`.zcompdump*`, `*.zwc` など）を除外 |
| `abbr.zsh` | zsh-abbr の略語定義（`g`→`git`、`hms`→home-manager switch など）。`ABBR_USER_ABBREVIATIONS_FILE` として zsh-abbr が直接読む |
| `aliases.zsh` | alias と小物関数。eza/bat への置き換え、`mkcd`、ファイルパスを許容する `cd` ラッパー、グローバルエイリアス（`L`, `G`, `C` など）、WSL/Linux のクリップボード |
| `keybinds.zsh` | キーバインドの集約先（emacs ベース）。fzf ウィジェットや zsh-abbr 展開のバインドもここに置く |
| `check.zsh` | シェル起動時の更新チェック。sheldon/brew は週次で自動更新チェック、nix（flake.lock と home-manager profile の差・上流の新コミット）・sheldon・brew の要更新通知は日次 |
| `load-log.zsh` | `_load_begin` / `_load_end`。対話シェルでのみ、各初期化ブロックの読み込み時間をログ出力する |
| `mac.zsh` | macOS 専用。Homebrew shellenv・site-functions、iTerm2 shell integration |
| `wsl.zsh` | WSL 専用。`open` コマンドの Windows 連携 |
| `langs/` | 言語ごとの環境設定。現在 source しているのは `rust.zsh` のみで、`ruby.zsh`（rbenv）・`python.zsh`（pyenv）・`go.zsh` は `.zshrc` でコメントアウト中 |

### source されないスクリプト

| ファイル | 役割 |
| --- | --- |
| `measure.zsh` | 起動時間計測（zprof）の on/off をトグルする手動実行スクリプト。`.zshenv`/`.zshrc` を一時的に書き換える |
| `tools.zsh` | ツール一括インストール用スクリプト（WIP）。手動実行想定 |

## ディレクトリ外との関係

- `../sheldon/plugins.toml` — sheldon のプラグイン定義（`.zshrc` の `sheldon source` が参照）
- `../fzf/fzf.functions.zsh` — fzf ウィジェットの関数定義。キーバインドは `keybinds.zsh` 側に集約
- `../utils/utils.bash` — `is_mac` / `is_wsl` / `is_linux` / `is_cmd_exists` などの判定関数
- `~/.local/zsh/*.zsh` — マシン固有設定（dotfiles 管理外）。`DOTFILES_MACHINE` の export など（[nix/README.md](../nix/README.md) 参照）
