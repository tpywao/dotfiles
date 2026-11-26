# utils

`utils/install-common.sh` は各 `install.sh` が source する共通部。`refuse_worktree()`、`link_config()`、`merge_config()`、`log_tag()`、`notice()` を定義し、`utils/utils.bash` を読み込む。

## 共通部の関数

- `refuse_worktree()` は source した時点で走り、worktree からの実行なら `exit 1` する。サブの `install.sh` も単体で実行できるので共通部に置いている。`DOTFILES_ALLOW_WORKTREE=1` で通せる。共通部を source するか `install.sh` を実行するテストは、worktree の中でも流れるよう先頭でこの変数を export する
- `link_config()` はリンクの有無だけでなく**リンク先**を検証し、違う先を指していれば張り替える。リンク先に実体があるときは、ファイルは内容が一致すれば置き換え・分岐していれば `.presymlink.<ts>` へ退避、ディレクトリは内容を比較せず常に退避する。親ディレクトリの作成も関数内で行うので、呼び出し側に `mkdir -p` は要らない
- `merge_config <src> <dst> [<jq フィルタ>]` は JSON の共有キーだけを既存の設定へ上書き適用する（どのファイルに使うかはルートの `AGENTS.md` の「アプリ自身が書き込む設定ファイル」）。フィルタは `.[0]` を `dst`、`.[1]` を `src` として受け取り、既定は再帰マージ（`.[0] * .[1]`）。第 4 引数以降に渡したファイルは `.[2]` 以降になる
  - マージ結果を確定させる前に「`dst` にあって結果に無い配列要素」を洗い出し、見つかれば `[dropped]` で列挙して `.premerge.<ts>` へ退避する。`src` と突き合わせるのではなく**マージ結果**と突き合わせるので、呼び出し側が渡すフィルタが何をするかに依存しない
- `notice() <文言>` はインストール後にユーザ自身が実行しないと解決しない作業を積む。ルートの `install.sh` が受け皿の一時ファイルのパスを `DOTFILES_NOTICES` で渡し、全ディレクトリの実行後に `-----> TODO` としてまとめて表示する。サブプロセスから親へ値を返せないためファイルを経由する（各 `install.sh` を単体で実行したときは変数が無いので、その場で出力する）
- `link_config()` などインストール時にしか使わない関数を `utils/utils.bash` に置かない。`utils.bash` は `zsh/.zshenv` から全 zsh 起動で source されるため、常駐させることになる

`utils/install-common.sh` を変更したら、`tests/utils/` のテスト 4 本（`link-config_test.sh`・`merge-config_test.sh`・`notice_test.sh`・`refuse-worktree_test.sh`）をすべて `sh` で流す。

## 出力の書式

3 系統に分ける。

- **対象ごとの結果**は `log_tag <色> <[タグ]> <対象>` でタグ付き 1 行にする（`[linked]` / `[new]` / `[relinked]` / `[replaced]` / `[dropped]` / `[backup]` / `[merged]` / `[imported]` / `[current]` / `[applied]` / `[installed]` / `[skipped]` / `[unlinked]` / `[failed]`）。色はシアン=変化なし、緑=新規、黄=既存を動かした、赤=失敗
- **対象を持たない進行ログ**（`-----> Switching home-manager` など）は `----->` のままにする
- **ユーザ自身がコマンドを打つまで解決しない作業**は `notice()` で末尾へ回す（タグ 1 行は出力が長いと流れてしまい、残タスクの提示には向かない）

## `[dropped]` が出たときの復旧

`merge_config` は配列を再帰マージせず `src` の内容で置換するため、`dst` にしか無い配列要素は失われる。アプリが書き込む値が配列に入るキー（`permissions.allow` に「常に許可」で追加されたルールなど）がこれに該当する。消えた要素は `[dropped]` で列挙され、マージ前の `dst` は `.premerge.<ts>` に残る。復旧の選択肢は 2 つ。

- **恒久化**: 残したい要素を dotfiles 側の `src` に追記して再実行する。dotfiles 側が正なので全マシンへ配布される
- **その場の復旧**: `.premerge.<ts>` を `dst` へ戻す。ただし dotfiles 側の更新も巻き戻り、次の実行で再び `[dropped]` になる

そのマシンだけで使いたい許可は、グローバルではなくプロジェクトの `.claude/settings.local.json` に置く（`merge_config` の対象外なので消えない）。
