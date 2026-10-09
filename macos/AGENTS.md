# macOS システム設定（macos）

- `macos/install.sh` が `defaults` でシステム設定を適用する。詳細は `macos/README.md`
- **型は実機から読み取ったものをそのまま使う。** macOS は同じ意味のキーでもドメインごとに型を変えて書いており（トラックパッドの `Dragging` は内蔵が integer、Bluetooth が boolean）、揃えると元の状態を再現できない。型は `defaults export <ドメイン> - | plutil -convert xml1 -o - -` で確認する（`defaults read` では bool と int を区別できない）
- **bool は `write_bool` を使う。** `defaults write -bool` が受け付けるのは `true/false/yes/no` だけで、`1` を渡すと usage を出して何も書かない。一方 `defaults read` は `1/0` を返すため、書き込みと比較で表記が違う
- 値が入れ子の dict / array になるものは平文で書けないので plist から `defaults import` する（`symbolichotkeys.plist`、`input-sources.plist`）。**この 2 つは自動生成ファイル。** 手書きせず `macos/README.md` の生成コマンドを流す
- **状態として書き換わる値は入れない**（Finder の `ShowSidebar` はサイドバーを開閉するたびに書き換わる）。追加前に時間を空けて 2 回 `defaults read` を取り、差分が出ないことを確かめる
- **TCC 保護ドメインは入れない**（`com.apple.universalaccess`）。`defaults write` が `Could not write domain <ドメイン>; exiting` で拒否される。通すには実行中のターミナルへフルディスクアクセスが要るが、その権限はターミナル本体に付いて配下の全コマンドへ継承されるため与えない。`[skipped]` を出し、設定する項目を `notice()` で末尾の TODO に積む（項目と対応するキーは `macos/README.md`）
- `macos/install.sh` を変更したら `sh tests/macos/install_test.sh` を流す。`defaults` と `killall` をスタブに差し替えて実機の設定には触れず、1 回目に全 `write_*` 行が書き込むこと・2 回目に 1 件も書かないこと・TCC 保護ドメインが毎回 `[skipped]` と手順の案内を出すことをケースにしてある
