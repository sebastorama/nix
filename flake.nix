{
  description = "Multi-platform system flake";

  inputs = {
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.url = "github:LnL7/nix-darwin";

    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    herdr.url = "github:ogulcancelik/herdr";
    herdr-recent-navigator = {
      url = "github:beyondlex/herdr-recent-navigator";
      flake = false;
    };

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

    nixos-wsl.url = "github:nix-community/nixos-wsl";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nix-darwin, nixpkgs, home-manager, nixos-wsl, ... }@inputs:
  let
    mkPkgs = system: import nixpkgs {
      inherit system;
      overlays = [
        inputs.neovim-nightly-overlay.overlays.default
        (final: prev: {
          neovim-unwrapped = prev.neovim-unwrapped.overrideAttrs (_: {
            doCheck = false;
            doInstallCheck = false;
          });
          pipx = prev.pipx.overrideAttrs (_: {
            doCheck = false;
            doInstallCheck = false;
          });
        })
      ];
      config.allowUnfree = true;
    };

    mkDarwinSystem = hostname: system: nix-darwin.lib.darwinSystem {
      modules = [
        ./darwin.nix
        { nixpkgs.pkgs = mkPkgs system; }
        home-manager.darwinModules.home-manager {
          users.users.sebastorama = {
            name = "sebastorama";
            home = "/Users/sebastorama";
          };
          home-manager.useGlobalPkgs = true;
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.sebastorama = import ./home.nix;
        }
      ];
      specialArgs = {
        inherit inputs hostname;
        system = system;
        self = self;
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

    mkNixosWslSystem = hostname: system: nixpkgs.lib.nixosSystem {
      # `system` intentionally not passed here: the platform comes from the
      # pre-built pkgs injected via nixpkgs.pkgs (readOnlyPkgs disables the
      # nixpkgs.system option).
      modules = [
        ./wsl_configuration.nix
        nixos-wsl.nixosModules.default
        nixpkgs.nixosModules.readOnlyPkgs
        { nixpkgs.pkgs = mkPkgs system; }
      ];
      specialArgs = {
        inherit inputs hostname self;
      };
    };
  in
  {
    # Darwin configurations
    darwinConfigurations = {
      "14m3" = mkDarwinSystem "14m3" "aarch64-darwin";
      "16m3" = mkDarwinSystem "16m3" "aarch64-darwin";
    };

    # NixOS configurations
    nixosConfigurations = {
      "wsl" = mkNixosWslSystem "wsl" "x86_64-linux";
    };

    # Home Manager configurations for non-NixOS Linux (standalone WSL distros)
    homeConfigurations = {
      "sebastorama@wsl" = mkHomeConfiguration "linux" "x86_64-linux";
    };

    # Expose activation packages for easier building
    packages.x86_64-linux.default = self.homeConfigurations."sebastorama@wsl".activationPackage;

    # Expose the package sets for convenience
    darwinPackages = self.darwinConfigurations."14m3".pkgs;
  };
}
