{
  description = "Multi-platform system flake";

  inputs = {
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.url = "github:LnL7/nix-darwin";

    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
  };

  outputs = { self, nix-darwin, nixpkgs, home-manager, ... }@inputs:
  let
    mkPkgs = system: import nixpkgs {
      inherit system;
      overlays = [inputs.neovim-nightly-overlay.overlays.default];
      config.allowUnfree = true;
    };

    mkDarwinSystem = hostname: system: nix-darwin.lib.darwinSystem {
      modules = [
        ./darwin.nix
        home-manager.darwinModules.home-manager {
          users.users.sebastorama = {
            name = "sebastorama";
            home = "/Users/sebastorama";
          };
          home-manager.useGlobalPkgs = true;
          home-manager.users.sebastorama = import ./home.nix;
        }
      ];
      specialArgs = {
        inherit inputs hostname;
        system = system;
        self = self;
        pkgs = mkPkgs system;
      };
    };

    mkHomeConfiguration = hostname: system: home-manager.lib.homeManagerConfiguration {
      pkgs = mkPkgs system;
      modules = [
        ./home.nix
      ];
      extraSpecialArgs = {
        inherit inputs hostname;
        system = system;
      };
    };
  in
  {
    # Darwin configurations
    darwinConfigurations = {
      "14m3" = mkDarwinSystem "14m3" "aarch64-darwin";
      "16m3" = mkDarwinSystem "16m3" "aarch64-darwin";
    };

    # Home Manager configurations for Linux
    homeConfigurations = {
      "sebastorama@wsl" = mkHomeConfiguration "linux" "x86_64-linux";
    };

    # Expose activation packages for easier building
    packages.x86_64-linux.default = self.homeConfigurations."sebastorama@wsl".activationPackage;

    # Expose the package sets for convenience
    darwinPackages = self.darwinConfigurations."14m3".pkgs;
  };
}
