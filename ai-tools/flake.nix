{
  description = "AI tools development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-26.05-darwin";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs
            git  # 一部のツールで必要
          ];

          shellHook = ''
            # npm グローバルキャッシュをプロジェクトローカルに設定
            export npm_config_prefix="$PWD/.npm"
            export PATH="$PWD/.npm/bin:$PATH"

            # 初回アクティベーション時にツールをインストール
            if [ ! -d "$PWD/.npm/lib/node_modules/ccusage" ]; then
              echo "Installing AI tools..."
              npm install -g ccusage repomix @colbymchenry/codegraph 2>/dev/null || true
              echo "Installation complete. Run 'ccusage', 'repomix', or 'codegraph' to use."
            fi
          '';
        };
      }
    );
}
