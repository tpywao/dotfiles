# ai-tools

AI 関連 CLI ツール（ccusage / codegraph、ほか ax / actionlint）を Nix flake で一元管理する。home-manager に統合済みのため、`home-manager switch` すれば各ツールは `~/.nix-profile/bin` に入り常に PATH 上にある（`cd` や `nix develop` は不要）。

## ファイル一覧

| ファイル | 役割 |
| --- | --- |
| `flake.nix` | npm ツール 2 つを `buildNpmPackage` で単一 derivation として定義。ax（flake input）と actionlint（nixpkgs）も packages として提供 |
| `flake.lock` | flake input のロック（自動生成。手書き編集しない） |
| `package.json` | npm ツールのバージョン固定（exact version）と `overrides` |
| `package-lock.json` | 推移的依存まで固定する lockfile（自動生成。手書き編集しない） |
| `.envrc` | `use flake`（direnv で dev shell に入る。lockfile 再生成作業用） |

## パッケージング方式の要点

- 依存取得は `fetchNpmDeps`（fixed-output derivation）による hash 検証つきオフラインビルド。実行時にレジストリへアクセスしない（サプライチェーン対策として npx 方式から移行）
- `npmFlags = [ "--ignore-scripts" ]` — install スクリプト（npm マルウェアの主要経路）を実行しない。**外さないこと**
- **`runCommand` + `npm install` に戻さないこと** — Nix ビルドサンドボックスはネットワーク不可で、失敗が握りつぶされ空の derivation が「成功」してしまう
- ccusage の native バイナリは実行ビット欠落のためビルド時に `chmod +x`（read-only store では実行時 chmod が EPERM になる）

## ツールの更新手順

1. `package.json` のバージョンを上げる
2. `cd ai-tools && npm install --ignore-scripts` で lockfile を再生成
3. `flake.nix` の `npmDepsHash` を再計算 — いったん `lib.fakeHash` にして `nix build` し、hash mismatch エラーの `got:` の値を転記する
   - `prefetch-npm-deps` は `npmDepsFetcherVersion = 2` と hash 形式が合わず使えない
   - `npmDepsFetcherVersion` を変えた場合も再計算が必要
4. `home-manager switch --flake "$DOTFILES#$DOTFILES_MACHINE" --impure` で反映

各ツールの使い方はリポジトリルートの [CLAUDE.md](../.claude/CLAUDE.md) の「AI ツール」セクションを参照。
