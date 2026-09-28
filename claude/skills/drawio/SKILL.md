---
name: drawio
description: Use when draw.io（diagrams.net）の図を作る・直すとき。.drawio を生成して SVG / PNG に書き出す、AWS 構成図を公式アイコンで描く、あとから人が編集できる形で図を残す、書き出した図をページや Artifact に埋め込むときに使う。閲覧専用の HTML 図でよければ archify を使う。
---

# drawio — draw.io で図を作る

## 概要

`.drawio` は mxGraph の XML なので、ファイルとして生成・編集できる。draw.io デスクトップに付属する CLI で SVG / PNG へ書き出す。

あとから人が draw.io で開いて直せる形で図を残したいときに使う。

- アプリ: `/Applications/draw.io.app`
- CLI: `/opt/homebrew/bin/drawio`

## 書き出し

```bash
drawio --export --format svg --theme auto --embed-svg-fonts false --border 20 --output out.svg in.drawio
```

- `--theme auto`（既定）だと色が `light-dark(明るいときの色, 暗いときの色)` として出力され、ビューアのテーマに追従する。`light` / `dark` を指定すると色が焼き付き、逆のテーマで読めなくなる
- `--embed-svg-fonts false` を付ける。日本語フォントが埋め込まれるとサイズが膨らむ
- 目視確認用は `--format png --theme light`

## AWS 構成図

シェイプの識別子は記憶で書かない。draw.io 本体の定義から引く。

```bash
ax https://raw.githubusercontent.com/jgraph/drawio/dev/src/main/webapp/js/diagramly/sidebar/Sidebar-AWS4.js --body > aws4.js
```

- リソース: `shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.<name>`
- グループ: `shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_aws_cloud` / `group_region` / `group_vpc2` / `group_security_group`
  - パブリック・プライベートサブネットは `group_security_group` を色違いで流用する
  - アベイラビリティゾーンだけはグループ図形がなく、破線の矩形で表す
- 塗り色は変数 `n` / `n2` に入っていて、**パレットごとに再定義される**。ファイル冒頭の `n2` は `fillColor=#232F3E`（ほぼ黒）なので、これを全アイコンに使うと図が真っ黒になる。各サービスの定義行より上にある直近の `var n2` を見る
- 同じサービスが複数のパレットにあり、色が違うことがある。Elastic Load Balancing は Compute のオレンジ（`#ED7100`）と Networking の紫（`#8C4FFF`）の両方にある。図の文脈で選ぶ

カテゴリ色: Networking `#8C4FFF` / Compute `#ED7100` / Database `#C925D1` / Storage `#7AA116`

## 結線

自動ルーティングに任せると、線がアイコンを貫通する。接続する辺と経路を明示する。

```xml
<mxCell id="e1" edge="1" parent="1" source="alb" target="fargate"
        style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;exitX=0.5;exitY=1;exitDx=0;exitDy=0;entryX=0.5;entryY=0;entryDx=0;entryDy=0;">
  <mxGeometry relative="1" as="geometry">
    <Array as="points">
      <mxPoint x="850" y="880" />
    </Array>
  </mxGeometry>
</mxCell>
```

- エッジの `parent` が `1` なら経由点は絶対座標。図形が入れ子（VPC > AZ > サブネット）のときは、親の座標を足して絶対座標を出してから指定する
- 同じ向きの線が複数あるときは、経由点の y（または x）を 20px 以上ずらして分離する。同じ高さに並べるとラベルが重なって読めなくなる
- 線が増えて交差するなら、線を引くのをやめて注記に落とす方が読みやすい。「両 AZ から同じリソースへ」のような対称な関係は、片方だけ結線して残りを注記に書く

## ダークモード

色を明示指定するとテーマ反転が効かなくなる。

- 文字色（`fontColor`）は指定せず既定に任せる。テーマに追従する
- 明るい塗り（`fillColor`）の領域に文字を置くと、ダークで白文字になって読めない。塗りを `none` にするか、その領域だけ文字色を固定する
- 暗い色を明示するのは、その要素がテーマ追従しなくてよいと判断したときだけにする

## 確認

書いた時点では必ず重なりが残っている。出す前に PNG で見る。

```bash
drawio --export --format png --theme light --output check.png in.drawio
```

Read で画像を開き、線の貫通・ラベルの重なり・枠からのはみ出しを確認する。見るのは 1 回にまとめ、見つけた分を一度に直す。

## ページや Artifact への埋め込み

書き出した SVG の先頭には `<!DOCTYPE svg PUBLIC ...>` が付く。Artifact の補助ファイルは DTD を含められず、publish 全体が拒否される（`supporting file ... carries a DOCTYPE or ENTITY declaration`）。レンダリングには不要なので削る。

```bash
perl -i.bak -ne 'next if /^<!DOCTYPE svg/; print' out.svg && rm out.svg.bak
```

`<?xml version="1.0" encoding="UTF-8"?>` は DTD ではないので残してよい。

`<img>` で参照すると SVG は独立したドキュメントとして描画され、テーマ判定は OS の設定（`prefers-color-scheme`）に従う。ページ側のテーマ切り替えにも追従させたいなら、インラインで展開する。
