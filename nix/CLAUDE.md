# nix

- **マシンごとの構成**: `homeConfigurations` はマシンごとにエントリを持ち（例: `work-mac`）、共通の `home.nix` ＋マシン固有モジュール（例: `work-mac.nix`、`common.nix` を imports）を組み合わせる。適用先は環境変数 `DOTFILES_MACHINE` で選択し、dotfiles 管理外の `~/.local/zsh/*.zsh` で export する。**未設定時に別マシンの構成へフォールバックすることはない**（fail-fast）。`nix/install.sh` は `~/.local/zsh/*.zsh` に保存済みの有効な export があればそれを使い、無ければ対話実行時のみ選択メニューを提示して `~/.local/zsh/machine.zsh` に永続化、非対話実行ではエラーで止まる（`home-manager switch` 単体も未設定はエラー）。マシン追加手順は `nix/README.md` を参照
  - `home.packages` はリスト型オプションで、複数モジュールの定義は自動的に concat（マージ）される（後勝ち上書きではない）。マシン固有パッケージは `work-mac.nix` に追加分だけ列挙する（`packages.nix` を再 import すると二重登録になる）
  - 共通パッケージは `nix/packages.nix`、マシン固有は `nix/work-mac.nix` に書く
