# macos

macOS のシステム設定（`defaults`）をマシン間で揃える。`macos/install.sh` が `defaults write` と `defaults import` で適用する。書き込み先はユーザーのドメインなので `sudo` は要らない。

Linux では `is_mac` のガードで何もせず抜ける。

## ファイル一覧

| ファイル | 内容 |
| --- | --- |
| `install.sh` | `defaults write` で書ける設定。ドメインごとに節を分けてある |
| `symbolichotkeys.plist` | キーボードショートカット（`com.apple.symbolichotkeys`）。自動生成 |
| `input-sources.plist` | 入力ソース（`com.apple.HIToolbox`）。自動生成 |

## 平文と plist を使い分ける理由

値が入れ子の dict / array になるものは `defaults write` に平文で書けないため plist から `defaults import` する。ショートカットはさらに、キーが数値 ID（`15`, `52`, ...）で Apple が意味を公開していないため、平文化しても読めるようにならない。

`defaults import` は plist に載っているキーだけを上書きし、配布先にしか無いキーはそのまま残す（ドメイン全体の置換ではない）。裏を返すと **dotfiles 側でキーを消しても配布先からは消えない**。消したいマシンでは `defaults delete <ドメイン> <キー>` を打つ。

## plist の再生成

手書きしない。設定を変えたら、変えたマシンで生成コマンドを流し直す。

```sh
# ショートカット
$ defaults export com.apple.symbolichotkeys - \
    | plutil -convert xml1 -o macos/symbolichotkeys.plist -

# 入力ソース（状態として書き換わるキーを落としてから保存する）
$ defaults export com.apple.HIToolbox - \
    | plutil -remove AppleCurrentKeyboardLayoutInputSourceID -o - - \
    | plutil -remove AppleDictationAutoEnable -o - - \
    | plutil -remove AppleFnUsageType -o - - \
    | plutil -remove AppleInputSourceHistory -o - - \
    | plutil -remove AppleInputSourceUpdateTime -o - - \
    | plutil -remove AppleSavedCurrentInputSource -o - - \
    | plutil -convert xml1 -o macos/input-sources.plist -
```

`AppleInputSourceHistory` などを落とすのは、これらが「最後に使った入力ソース」を持つ状態で、残すと配布先のマシンへ他マシンの利用履歴が流れ込むため。`AppleDictationAutoEnable` と `AppleFnUsageType` は `install.sh` 側に平文で書いてあるので plist からは外す。

## 設定を足す手順

1. 対象のキーの型を調べる。`defaults read` では bool と int が区別できないので XML で見る

```sh
$ defaults export com.apple.dock - | plutil -convert xml1 -o - - \
    | rg -A 1 '<key>tilesize</key>'
	<key>tilesize</key>
	<real>46</real>
```

2. 型に応じて `install.sh` へ 1 行足す。bool だけは `write_bool` を使う

```sh
write_default com.apple.dock tilesize -float 46   # real  -> -float
write_default com.apple.dock wvous-br-corner -int 1
write_default com.apple.dock orientation -string left
write_bool com.apple.dock autohide true           # true/false -> write_bool
```

`write_default` の値は `defaults read` が返す表記で書く。現在値との比較にそのまま使うため。bool を `write_default` で書けないのは、`defaults write -bool` が受け付けるのが `true/false/yes/no` だけなのに対し `defaults read` は `1/0` を返すから（`-bool 1` は usage を出して何も書かない）。

3. `sh tests/macos/install_test.sh` を流す

型は実機から読み取ったものをそのまま使う。macOS は同じ意味のキーでもドメインごとに型を変えて書いており（トラックパッドの `Dragging` は内蔵が integer、Bluetooth が boolean）、揃えると元の状態を再現できない。

## 入れていない設定

### 状態として書き換わる値

Finder の `ShowSidebar` は入れていない。サイドバーの表示/非表示を切り替えるたびに Finder が書き換えるため、インストール時点の状態を焼き付けるだけになる。同じ理由でウインドウ位置・最近使った項目・各種 `Upgraded*` フラグも対象外。

新しいキーを足すときは、しばらく間を空けて 2 回 `defaults read <ドメイン>` を取り、差分が出ないことを確かめてからにする。

### `defaults` の管轄外

以下は `defaults` から書けないため手動で設定する。

- **壁紙**: システム設定 > 壁紙。保存先は `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist` で、値は入れ子の binary plist
- **ロック画面のパスワード要求**: `sysadminctl -screenLock immediate -password <パスワード>`。対話でパスワードを求められるためスクリプト化できない。現在値は `sysadminctl -screenLock status` で確認する
- **Dock に並べるアプリ**: `persistent-apps` は絶対パスを持つ。マシンによって入っているアプリが違うため入れていない

## 反映のタイミング

`defaults write` の結果は、対象のプロセスを再起動するまで画面に出ない。`install.sh` の末尾で `killall Dock Finder SystemUIServer` を実行している。

トラックパッド・キーボード・アクセシビリティの一部は再ログインまで反映されないことがある。
