Metabase カードのパラメータ並び順を変更してください。

## 手順

1. ユーザーからカード ID を受け取る（引数があれば `$ARGUMENTS` から取得、なければ確認する）
2. Metabase MCP の `get_card` ツールでカード情報を取得し、現在の `parameters` の順番を番号付きで表示する（slug と name を並べて表示）
3. ユーザーに理想の並び順を slug または番号で指定してもらう（番号指定の場合は内部で slug に変換する）
4. 指定された順番で `parameters` 配列を並び替えた JSON を生成する（jq を使う）
   - MCP tool の結果がファイルに保存された場合、Read ツール出力には行番号プレフィックス（`1→`）がつく
   - `sed 's/^[[:space:]]*[0-9]*→//' <file> | jq -r '.[0].text' 2>/dev/null | jq '...' 2>/dev/null` のように2ステップで処理する
5. 適用後の順番をプレビュー表示してユーザーに確認を取る
6. 確認が取れたら `/Users/ogiso/apn/metabase/.env` から `METABASE_URL` と `METABASE_API_KEY` を読み込み、curl で `PUT /api/card/<card_id>` を実行する

## curl コマンド（更新時のみ使用）

```bash
curl -s -X PUT "$METABASE_URL/api/card/<card_id>" \
  -H "x-api-key: $METABASE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"parameters": <並び替え後のJSON>}'
```

jq を使って JSON を処理すること（python3 は使わない）

## バリデーション

- 指定された slug の数がカードのパラメータ数と一致しない場合はエラーを出す
- 存在しない slug が指定された場合もエラーを出す
