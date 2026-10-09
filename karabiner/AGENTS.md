# Karabiner-Elements 設定（karabiner）

- complex modifications（`Naginata.json`、`Personal.json`）は `~/.config/karabiner/assets/complex_modifications/` へ symlink する。Karabiner はこのディレクトリを読むだけで、リンクを壊さない（GUI のゴミ箱ボタンでルールを消したときだけ `unlink` する）
- **`karabiner.json` は symlink 管理できない。** Karabiner-Elements は設定を保存するたびにこのファイルを書き直し、その際 symlink を実体で置き換える。symlink のままだと外部からの変更検知（自動リロード）も効かない。共有したいキーは `karabiner/profile-defaults.json` に持ち、`merge_karabiner_profile` が `merge_config` へフィルタを渡して適用する
- `profile-defaults.json` が持つのは `name` / `devices` / `virtual_hid_keyboard` だけ。**`complex_modifications` の `rules` は持たない。** rules には assets/ 側のファイルを GUI で有効化した結果が入るため、両方から書くと二重管理になる
- `devices` は配列なので dotfiles 側の内容で置換される。マシン固有のデバイス設定を足したマシンでは `merge_config` が `[dropped]` で知らせる
- `name` をキーにプロファイルを特定する。プロファイル名を変えたマシンでは当たらず、`notice()` の TODO に出る
- assets/ に置いただけでは complex modification は効かない。常時有効にしたいルールは `Personal.json` に入れる（未有効なら TODO に出る）。`Naginata.json` は必要なときに GUI から選ぶための置き場で、TODO の対象外
- `karabiner/install.sh` を変更したら `sh tests/karabiner/install_test.sh` を流す。`$HOME` を一時ディレクトリへ差し替えて実機の `~/.config/karabiner` には触れず、`karabiner.json` の状態（未作成・プロファイル名違い・複数プロファイル・マシン固有デバイスあり）ごとの経路をケースにしてある
