{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-26.05-darwin";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ai-tools = {
      url = "path:./ai-tools";
    };
    dwt = {
      # タグ固定: nix flake update で main に追従しないようにする。
      # 更新手順: dwt 側でタグを打つ → ここの参照タグを書き換える
      url = "github:wao3299/dwt/v0.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ai-tools, dwt, ... }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
      username = builtins.getEnv "USER";
      ai-tools-pkgs = ai-tools.packages.${system};
      dwt-pkgs = dwt.packages.${system};
    in {
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit ai-tools-pkgs dwt-pkgs; };
        modules = [ ./nix/home.nix ];
      };
    };
}
