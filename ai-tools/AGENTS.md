# ai-tools

Claude Code 周辺のツール（ccusage, codegraph）を Nix flake で提供するディレクトリ。

- **ディレクトリ**: `ai-tools/`（dotfiles で管理。`flake.nix` からは `path:./ai-tools` で相対参照する）
- **flake.nix**: Node.js + 2つの開発ツール（ccusage, codegraph）を定義
- **常設**: ai-tools は home-manager に統合済み。`home-manager switch` すると codegraph/ccusage が `~/.nix-profile/bin` に入り**常に PATH 上**にある（`nix develop` は不要）
- **パッケージング方式**: `ai-tools/flake.nix` は `buildNpmPackage` + `package-lock.json` で 2 ツールを単一 derivation として提供（lockfile ベースの固定・オフラインビルド。#15/#20 でサプライチェーン対策として npx 方式から移行）
  - 依存取得は `fetchNpmDeps`（fixed-output derivation）による hash 検証つき。推移的依存まで lockfile で固定され、実行時にレジストリへアクセスしない
  - `npmFlags = [ "--ignore-scripts" ]`: install スクリプト（npm マルウェアの主要経路）は実行しない。外さないこと
  - **`runCommand`+`npm install` に戻さないこと**: Nix ビルドサンドボックスはネットワーク不可で、空の derivation を「成功」として生成してしまう（失敗が握りつぶされる）。`fetchNpmDeps` は fixed-output derivation なのでネットワーク可
  - **ツールの更新手順**: `ai-tools/package.json` のバージョンを上げ → `cd ai-tools && npm install --ignore-scripts` で lockfile を再生成 → `flake.nix` の `npmDepsHash` を再計算（いったん `lib.fakeHash` にして `nix build` し、hash mismatch エラーの `got:` の値を転記）。`npmDepsFetcherVersion` を変えた場合も hash の再計算が必要
- codegraph のフル再構築は `codegraph index`。`rebuild` というサブコマンドは無い
