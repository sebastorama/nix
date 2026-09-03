{
  description = "Multi-platform system flake";

  inputs = {
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.url = "github:LnL7/nix-darwin";

    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    herdr = {
      url = "github:ogulcancelik/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    herdr-recent-navigator = {
      url = "github:beyondlex/herdr-recent-navigator";
      flake = false;
    };
    herdr-navigator = {
      url = "github:willfish/herdr-navigator";
      flake = false;
    };
    herdr-bar = {
      url = "github:jeffarese/herdr-bar";
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
          # Upstream installs the dylibs with an `@rpath/...` install name, so
          # anything linking against them (curl-cffi -> yt-dlp) gets an
          # unresolvable `@rpath/libcurl-impersonate.4.dylib` reference.
          curl-impersonate = prev.curl-impersonate.overrideAttrs (old:
            nixpkgs.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
              postInstall = (old.postInstall or "") + ''
                for f in $out/lib/libcurl-impersonate*.dylib; do
                  [ -L "$f" ] || install_name_tool -id "$f" "$f"
                done
              '';
            });
          # Some curl-cffi tests fail on darwin (SSL error wording, websocket
          # frame sizes, cookie handling) and are unrelated to yt-dlp usage.
          pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
            (_: pyPrev: {
              curl-cffi = pyPrev.curl-cffi.overrideAttrs (_: {
                doCheck = false;
                doInstallCheck = false;
              });
            })
          ];
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
          home-manager.extraSpecialArgs = { inherit inputs hostname; };
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

    mkOrbstackSystem = hostname: system: nixpkgs.lib.nixosSystem {
      modules = [
        ./orbstack_configuration.nix
        nixpkgs.nixosModules.readOnlyPkgs
        { nixpkgs.pkgs = mkPkgs system; }
      ];
      specialArgs = {
        inherit inputs hostname self;
      };
    };

    mkNixosSystem = hostname: system: configuration: nixpkgs.lib.nixosSystem {
      modules = [
        configuration
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
      "nixos-orbstack" = mkOrbstackSystem "nixos-orbstack" "aarch64-linux";
      "nixos-dev" = mkNixosSystem "nixos-dev" "x86_64-linux" ./hosts/nixos-dev/configuration.nix;
      "nixos-sapb1" = mkNixosSystem "nixos-sapb1" "x86_64-linux" ./hosts/nixos-dev/configuration.nix;
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
