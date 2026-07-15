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
          # npm packages を runCommand で Nix derivation にラップ
          codegraph = pkgs.runCommand "codegraph-wrapper" {
            buildInputs = [ pkgs.nodejs ];
            preferLocalBuild = true;
            allowSubstitutes = false;
          } ''
            mkdir -p $out/bin
            export npm_config_prefix="$out"
            npm install -g @colbymchenry/codegraph 2>/dev/null || true
            # シンボリックリンク作成（bin/codegraph を $out/bin にコピー）
            if [ -f "$out/lib/node_modules/.bin/codegraph" ]; then
              cp "$out/lib/node_modules/.bin/codegraph" $out/bin/codegraph
              chmod +x $out/bin/codegraph
            fi
          '';

          ccusage = pkgs.runCommand "ccusage-wrapper" {
            buildInputs = [ pkgs.nodejs ];
            preferLocalBuild = true;
            allowSubstitutes = false;
          } ''
            mkdir -p $out/bin
            export npm_config_prefix="$out"
            npm install -g ccusage 2>/dev/null || true
            if [ -f "$out/lib/node_modules/.bin/ccusage" ]; then
              cp "$out/lib/node_modules/.bin/ccusage" $out/bin/ccusage
              chmod +x $out/bin/ccusage
            fi
          '';

          repomix = pkgs.runCommand "repomix-wrapper" {
            buildInputs = [ pkgs.nodejs ];
            preferLocalBuild = true;
            allowSubstitutes = false;
          } ''
            mkdir -p $out/bin
            export npm_config_prefix="$out"
            npm install -g repomix 2>/dev/null || true
            if [ -f "$out/lib/node_modules/.bin/repomix" ]; then
              cp "$out/lib/node_modules/.bin/repomix" $out/bin/repomix
              chmod +x $out/bin/repomix
            fi
          '';
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
