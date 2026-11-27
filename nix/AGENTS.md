# nix

- **マシンごとの構成**: `homeConfigurations` はマシンごとにエントリを持ち（例: `work-mac`）、共通の `home.nix` ＋マシン固有モジュール（例: `work-mac.nix`、`common.nix` を imports）を組み合わせる。適用先は環境変数 `DOTFILES_MACHINE` で選択し、dotfiles 管理外の `~/.local/zsh/*.zsh` で export する。**未設定時に別マシンの構成へフォールバックすることはない**（fail-fast）。`nix/install.sh` は `~/.local/zsh/*.zsh` に保存済みの有効な export があればそれを使い、無ければ対話実行時のみ選択メニューを提示して `~/.local/zsh/machine.zsh` に永続化、非対話実行ではエラーで止まる（`home-manager switch` 単体も未設定はエラー）。マシン追加手順は `nix/README.md` を参照
  - `home.packages` はリスト型オプションで、複数モジュールの定義は自動的に concat（マージ）される（後勝ち上書きではない）。マシン固有パッケージは `work-mac.nix` に追加分だけ列挙する（`packages.nix` を再 import すると二重登録になる）
  - 共通パッケージは `nix/packages.nix`、マシン固有は `nix/work-mac.nix` に書く

## shallow clone で置かない

**このリポジトリを shallow clone で置かない。** nix は flake の `revCount` を得るために履歴を全走査するため、shallow clone では境界の先を読もうとして `getting Git object '<sha>': object not found` で失敗する。`nix flake check` も `home-manager switch` も通らなくなる。

- nix のキャッシュに載っている rev では成功するので、しばらく気づかない。キャッシュに無い新しい rev ができた直後（コミットの組み直しなど）に露見する
- 判定は `git rev-parse --is-shallow-repository`、解消は `git fetch --unshallow`
- リポジトリ自体は壊れていないため `git fsck` では何も出ない。`nix flake check --impure "git+file:///path/to/repo"` と直接指定すると `is a shallow Git repository, so 'revCount' is not available` と出て原因が分かる
