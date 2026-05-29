# nix (home-manager)

## flake.lock の更新手順

`flake.lock` がしばらく更新されていない通知が来たら、以下を順に実行する。

1. 現状確認

```sh
$ stat -f "%Sm" flake.lock   # 最終更新日
$ git status --short          # 作業中の変更がないか
```

2. ロックファイル更新

```sh
$ nix flake update
```

home-manager / nixpkgs の更新差分（旧 rev → 新 rev）が表示される。

3. ビルド検証（switch する前に通るか確認）

```sh
$ nix build ".#homeConfigurations.$USER.activationPackage" --no-link --impure
```

`--impure` は必須。この flake は `builtins.getEnv "USER"` を使うため、付けないと attribute not found で落ちる。

4. 適用

```sh
$ hms   # abbr: nix run home-manager -- switch --flake "$DOTFILES#$(whoami)" --impure
```

5. コミット

`flake.lock` の更新は単独でコミットする（無関係な作業変更と混ぜない）。
