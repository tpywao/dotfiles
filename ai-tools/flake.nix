{
  description = "AI tools development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-26.05-darwin";
    flake-utils.url = "github:numtide/flake-utils";
    ax = {
      url = "github:yusukebe/ax";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { self, nixpkgs, flake-utils, ax }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # npm ツール群を package-lock.json で固定した単一 derivation
        # - 依存取得は fetchNpmDeps(fixed-output derivation)による hash 検証つきオフラインビルド
        # - --ignore-scripts: install スクリプト(npm マルウェアの主要経路)を実行しない
        # - 更新手順: package.json のバージョンを上げ npm install --ignore-scripts で
        #   lockfile を再生成し、npmDepsHash を prefetch-npm-deps で再計算する
        ai-tools-npm = pkgs.buildNpmPackage {
          pname = "ai-tools";
          version = "1.0.0";

          # flake.nix 等の変更で再ビルドされないよう src を manifest + lockfile に限定
          src = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [
              ./package.json
              ./package-lock.json
            ];
          };

          npmDepsHash = "sha256-3koutcfV9rCfSZEXFeu0ApP/+YYjuY8Zp/r3yhVJJJk=";
          # fetcher 形式を明示(lockfile 更新時は npmDepsHash と合わせて再計算)
          npmDepsFetcherVersion = 2;

          npmFlags = [ "--ignore-scripts" ];
          dontNpmBuild = true;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          # メタパッケージ自身に bin は無いので、依存の bin を $out/bin に束ねる
          # makeWrapper で nodejs を PATH に足す(ツールが node を子プロセス起動する場合に備える)
          installPhase = ''
            runHook preInstall

            mkdir -p $out/lib
            cp -r node_modules $out/lib/node_modules

            for tool in ccusage repomix codegraph; do
              makeWrapper "$out/lib/node_modules/.bin/$tool" "$out/bin/$tool" \
                --prefix PATH : "${pkgs.nodejs}/bin"
            done

            runHook postInstall
          '';
        };
      in
      {
        packages = {
          # ccusage / repomix / codegraph は同一 derivation から提供
          ai-tools = ai-tools-npm;
          default = ai-tools-npm;

          # npm 配布ではないため flake input から取得
          ax = ax.packages.${system}.ax;

          # npm ツールではないため nixpkgs のパッケージをそのまま提供
          actionlint = pkgs.actionlint;
        };

        # lockfile 再生成(npm install)用の開発シェル
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs
            git
          ];
        };
      }
    );
}
