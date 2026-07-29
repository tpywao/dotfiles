# nix (home-manager)

## マシンごとの構成

`flake.nix` の `homeConfigurations` はマシンごとにエントリを持つ。各エントリは共通の `nix/home.nix` に加えてマシン固有モジュール（例: `nix/work-mac.nix`）を読み込む。

適用先のマシン名は環境変数 `DOTFILES_MACHINE` で指定する（未設定時は `work-mac`）。マシン固有の設定なので dotfiles 管理外の `~/.local/zsh/*.zsh` で export する。

```sh
# ~/.local/zsh/machine.zsh（例）
export DOTFILES_MACHINE=work-mac
```

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
$ nix build ".#homeConfigurations.${DOTFILES_MACHINE:-work-mac}.activationPackage" --no-link --impure
```

`--impure` は必須。`home.nix` が `builtins.getEnv "USER"` を使うため、付けないと Username could not be determined で落ちる。

4. 適用

```sh
$ hms   # abbr: nix run home-manager -- switch --flake "$DOTFILES#${DOTFILES_MACHINE:-work-mac}" --impure
```

5. コミット

`flake.lock` の更新は単独でコミットする（無関係な作業変更と混ぜない）。
