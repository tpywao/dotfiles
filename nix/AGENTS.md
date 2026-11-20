# nix

- **マシンごとの構成**: `homeConfigurations` はマシンごとにエントリを持ち（例: `work-mac`）、共通の `home.nix` ＋マシン固有モジュール（例: `work-mac.nix`、`common.nix` を imports）を組み合わせる。適用先は環境変数 `DOTFILES_MACHINE` で選択し、dotfiles 管理外の `~/.local/zsh/*.zsh` で export する。**未設定時に別マシンの構成へフォールバックすることはない**（fail-fast）。`nix/install.sh` は `~/.local/zsh/*.zsh` に保存済みの有効な export があればそれを使い、無ければ対話実行時のみ選択メニューを提示して `~/.local/zsh/machine.zsh` に永続化、非対話実行ではエラーで止まる（`home-manager switch` 単体も未設定はエラー）。マシン追加手順は `nix/README.md` を参照
  - `home.packages` はリスト型オプションで、複数モジュールの定義は自動的に concat（マージ）される（後勝ち上書きではない）。マシン固有パッケージは `work-mac.nix` に追加分だけ列挙する（`packages.nix` を再 import すると二重登録になる）
  - 共通パッケージは `nix/packages.nix`、マシン固有は `nix/work-mac.nix` に書く
- **`stale-work-check`**（`stale-work-check.sh` / `.nix`）: PR を出していない自分のブランチと止まっている PR を GitHub から洗い出し、launchd で平日の朝夕に通知する。`work-mac.nix` から import している。対象のリポジトリは dotfiles 管理外の `~/.config/stale-work-check/config` に書く（書式はスクリプトの先頭）。dotfiles には固有のリポジトリ名を書かないため
  - 見るのは GitHub だけ。コミットは必ず push する運用（グローバルの `CLAUDE.md`）が前提で、手元にしか無いコミットや未コミットの変更は見えない
  - スクリプトを変更したら `sh tests/nix/stale-work-check_test.sh` を流す。gh と osascript はスタブに差し替えてある
  - テストは PATH の `bash`（macOS では標準の 3.2）で流れるので、スクリプトは bash 3.2 で動くように書く。`mapfile` などの bash 4 以降の機能は使わない。変数の直後に全角文字を続けるときは `${var}（` と波括弧で区切る（3.2 は `$var（` の全角文字まで変数名として読み、`unbound variable` で落ちる）
  - パッケージは `writeShellApplication` で作るので、ビルド時に shellcheck が通る必要がある。`# shellcheck disable=` は case の分岐の前には置けず、case 文の前に置く
