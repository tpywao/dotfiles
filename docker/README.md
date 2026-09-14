# docker (colima)

## 構成

コンテナの daemon は [colima](https://github.com/abiosoft/colima) が立てる Linux VM の中で動く。ホスト側に入れるのは CLI だけで、`nix/packages.nix` が次の 2 つを配布する。

- `colima` — VM の管理（Lima のラッパ）
- `docker-client` — `docker` CLI。daemon は含まない

compose と buildx は `docker-client` が実行時依存として持ち、CLI がその store パスをプラグインとして直接探索する。`docker compose` も `docker buildx` もこの 2 つだけで動くので、`docker-compose` / `docker-buildx` を別に並べる必要はない。認識状況は `docker info --format '{{json .ClientInfo.Plugins}}'` で確認できる。

Docker Desktop を使わないのは、Linux VM に加えて Electron の管理画面と常駐サービスを抱え、コンテナを動かしていない間もその分のメモリを占めるため。商用利用が無償（MIT）である点も条件に入る。`brew/Brewfile.gui` に Docker Desktop の cask は置かない。

## 初回セットアップ

`install.sh` は VM を作らない。作成・起動は手動で行う。

```sh
$ colima start --cpus 4 --memory 8
```

指定しなかった値は colima の既定が入る（CPU 2、メモリ 2 GiB、ディスク 100 GiB）。VM の種別は `vz`（Apple Virtualization.framework）、マウントは `virtiofs` がいずれも既定なので、明示する必要はない。

x86_64 のイメージを動かす場合は Rosetta を有効にする。

```sh
$ colima start --cpus 4 --memory 8 --vz-rosetta
```

起動時に指定したフラグは `~/.colima/default/colima.yaml` へ保存される（`--save-config` の既定が true）。2 回目以降は `colima start` だけでよい。

CPU のフラグは `--cpus`。`colima start --help` の例文には `--cpu` と書かれているが、フラグ一覧の表記は `--cpus` である。

## 日常の操作

```sh
$ colima start    # VM を起動する
$ colima stop     # VM を停止する（ディスクは残るので次回の起動は速い）
$ colima status   # 状態を見る
$ colima delete   # VM を破棄する（設定を変えて作り直すとき）
```

`colima start` は docker context を `colima` に切り替える（`--activate` の既定が true）。`docker` CLI はそのまま VM 内の daemon を向く。

CPU やメモリを変えるときは、`colima stop` のあとに新しい値を付けて `colima start` する。ディスクサイズだけは拡張のみで、縮小するには `colima delete` して作り直す。

## Docker Desktop との違い

`docker` CLI は upstream のものをそのまま使うため、サブコマンドの体系は変わらない。ポートの公開（`-p`）はホストの `localhost` に届き、`host.docker.internal` も解決する。差が出るのは次の点。

### ホストのディレクトリをマウントできる範囲

colima が VM へ渡すのは `$HOME` だけで、その外のパスはマウントされない。**`-v` に渡してもエラーにならず、意図したものとは違う中身が見える。** 壊れ方は 2 通りある。

VM にそのパスが存在しない場合は、空のディレクトリがマウントされる。

```sh
$ docker run --rm -v /private/etc:/x alpine ls /x   # 何も出ない
```

VM にも同じパスが存在する場合は、ホスト側ではなく **VM 自身のディレクトリ**が見える。中身があるぶん、こちらのほうが気づきにくい。

```sh
$ docker run --rm -v /tmp:/x alpine ls /x
systemd-private-...-systemd-logind.service-wLK7je    # VM の /tmp。Mac の /tmp ではない
```

macOS の `/tmp` は `/private/tmp` の実体、`$TMPDIR` は `/var/folders/...` で、いずれも `$HOME` の外にある。一時ディレクトリ経由でファイルを渡すツールはこれを踏む。

`$HOME` 配下のパスは通常どおり読み書きできる。named volume（`-v mydata:/var/lib/postgresql/data`）は VM の中で完結するため、この制限とは無関係に動く。

Docker Desktop は `/Users` `/Volumes` `/private` `/tmp` を既定でマウントしていた。`$HOME` の外を使う必要があるときは、マウント対象を明示して VM を作り直す。

```sh
$ colima stop
$ colima start --mount /path/to/dir:w   # :w で書き込み可
```

`~/.colima/default/colima.yaml` の `mounts` に書いてもよい。

設定ファイルが見つからない、データが毎回空になる、といった症状が出たらマウント元を疑う。上の `ls` でホスト側の中身が見えるかを確かめられる。

### VM を自分で起動する

Docker Desktop の自動起動・メニューバー常駐にあたるものは無い。`docker` を使う前に `colima start` する。

### GUI が無い

ダッシュボード、Extensions、Dev Environments は使えない。コンテナやイメージの一覧は `docker ps` / `docker images` で見る。

### Kubernetes

`colima start --kubernetes` で有効にする。Docker Desktop の設定画面にあたるものは無い。

## VM のパラメータを dotfiles で管理しない理由

割り当てる CPU・メモリはマシンの搭載量に依存し、共有できる値ではない。colima 自身が起動時のフラグを `~/.colima/default/colima.yaml` へ書き戻すため、dotfiles 側からこのファイルを配布するとマージが必要になるが、YAML なので `merge_config`（jq）では扱えず `yq` の追加が要る。管理対象はパッケージまでとし、VM の作成は各マシンで行う。

## install.sh が行うこと

`config.json` のマージのみ。dotfiles 側が持つのは `detachKeys` だけで、`credsStore` など Docker が自分で書き込む値には触らない（`merge_config` を使う理由は `.claude/CLAUDE.md` を参照）。
