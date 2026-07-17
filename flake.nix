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
  };

  outputs = { nixpkgs, home-manager, ai-tools, ... }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
      username = builtins.getEnv "USER";
      ai-tools-pkgs = ai-tools.packages.${system};
    in {
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit ai-tools-pkgs; };
        modules = [ ./nix/home.nix ];
      };
    };
}
