# nix (home-manager)

## マシンごとの構成

`flake.nix` の `homeConfigurations` はマシンごとにエントリを持つ。各エントリは共通の `nix/home.nix` に加えてマシン固有モジュール（例: `nix/work-mac.nix`）を読み込む。

適用先のマシン名は環境変数 `DOTFILES_MACHINE` で指定する。**未設定時に別マシンの構成へフォールバックすることはない**（設定し忘れたマシンに別マシンの構成が黙って当たるのを防ぐため）。`home-manager switch`（`hms`）や非対話実行の `install.sh` はエラーで止まり、対話実行の `install.sh` のみ選択メニューを提示する（後述）。マシン固有の設定なので dotfiles 管理外の `~/.local/zsh/*.zsh` で export する。

```sh
# ~/.local/zsh/machine.zsh（例）
export DOTFILES_MACHINE=work-mac
```

`install.sh` は `DOTFILES_MACHINE` が未設定のとき、対話実行（stdin が tty）なら `flake.nix` の `homeConfigurations` から選択肢を提示して選ばせる。非対話実行（パイプ・CI）ではメニューを出さずエラー終了する。選択結果は `~/.local/zsh/machine.zsh` に保存される。ただし既存の `~/.local/zsh/*.zsh` に `export DOTFILES_MACHINE=...` が既にある場合は新たに作成せず、そのファイルの更新を促すメッセージを出す（`*.zsh` はアルファベット順に source されるため、後から作ったファイルが既存の設定を黙って上書きするのを防ぐ）。

### マシンの追加手順

1. `nix/<machine>.nix` を作成する（`common.nix` を imports し、そのマシン固有のパッケージ・設定を書く。`work-mac.nix` を参考に）
2. `flake.nix` の `homeConfigurations` に `<machine> = mkHome ./nix/<machine>.nix;` を追加する
3. 新マシンの `~/.local/zsh/` で `export DOTFILES_MACHINE=<machine>` を設定する

## flake.lock の更新手順

`flake.lock` がしばらく更新されていない通知が来たら、以下を順に実行する。

1. 現状確認

```sh
$ stat -f "%Sm" flake.lock   # 最終更新日
$ git status --short          # 作業中の変更がないか
```

2. ロックファイル更新

```sh
$ nfu   # nix flake update --flake "$DOTFILES"
```

home-manager / nixpkgs の更新差分（旧 rev → 新 rev）が表示される。

3. ビルド検証（switch する前に通るか確認）

```sh
$ nix build ".#homeConfigurations.$DOTFILES_MACHINE.activationPackage" --no-link --impure
```

`--impure` は必須。`home.nix` が `builtins.getEnv "USER"` を使うため、付けないと Username could not be determined で落ちる。

4. 適用

```sh
$ hms   # abbr: home-manager switch --flake "$DOTFILES#${DOTFILES_MACHINE:?see nix/README.md}" --impure
```

`home-manager` コマンドは `programs.home-manager.enable` により初回 switch 以降 PATH に入る（flake.lock で pin された版が使われる）。新マシンでまだ入っていない初回だけは `nix run` 経由で実行する:

```sh
$ nix run home-manager -- switch --flake "$DOTFILES#${DOTFILES_MACHINE:?see nix/README.md}" --impure
```

5. コミット

`flake.lock` の更新は単独でコミットする（無関係な作業変更と混ぜない）。
