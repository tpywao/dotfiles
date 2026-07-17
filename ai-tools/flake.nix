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
        packages = {
          # npx ラッパースクリプトでツール実行
          # --yes: 非TTY(Claude Code フック等)で「Ok to proceed?」プロンプトを出さない
          codegraph = pkgs.writeShellScriptBin "codegraph" ''
            exec ${pkgs.nodejs}/bin/npx --yes @colbymchenry/codegraph "$@"
          '';

          ccusage = pkgs.writeShellScriptBin "ccusage" ''
            exec ${pkgs.nodejs}/bin/npx --yes ccusage "$@"
          '';

          repomix = pkgs.writeShellScriptBin "repomix" ''
            exec ${pkgs.nodejs}/bin/npx --yes repomix "$@"
          '';

          # npm ツールではないため nixpkgs のパッケージをそのまま提供
          actionlint = pkgs.actionlint;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs
            git
          ];

          shellHook = ''
            export npm_config_prefix="$PWD/.npm"
            export PATH="$PWD/.npm/bin:$PATH"

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
