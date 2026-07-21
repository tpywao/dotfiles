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
      url = "github:wao3299/dwt";
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
