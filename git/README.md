# git

git のグローバル設定とフックスクリプト。

## ファイル一覧

| ファイル | 役割 |
| --- | --- |
| `gitconfig` | グローバル git 設定。`install.sh` が `~/.gitconfig` へ symlink する |
| `gitignore` | グローバル gitignore 用ファイル。**現状どこからも参照されていない**（`core.excludesFile` 未設定、install.sh でもリンクされない） |
| `hooks/` | フックスクリプト置き場。**現状自動では配線されていない**（下記） |

## gitconfig の要点

- エイリアス多数（`st`, `hist`, `cpush`, `brprune` など）
- pager / diffFilter は delta があれば delta、なければ cat にフォールバック
- `[include] path = ~/.gitconfig.local` — user.name / user.email などマシン固有設定はローカル側に置く（install.sh が作成を促す）
- `pull.ff = only`, `fetch.prune = true`, `rebase.autosquash = true`, `init.defaultBranch = main`

## hooks/

| スクリプト | 役割 |
| --- | --- |
| `commit-msg` | ブランチ名（`<type>/<ticket>` 形式）からチケット名を取り、コミットメッセージを検証 |
| `pre-commit` | main / master / develop / test への直コミットを禁止 |
| `pre-push` | 同ブランチへの直プッシュを禁止 |
| `prepare-commit-msg` | ブランチ名のチケット名をコミットメッセージに自動付与（WIP） |
| `prepare-commit-msg.py` | 上記の Python 書き直し（WIP、未使用） |

`install.sh`・`gitconfig` のどちらからも参照されていないため、使うには対象リポジトリの `.git/hooks/` へコピーするか、`core.hooksPath` をこのディレクトリに向ける必要がある。
