{
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
        nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    };

    outputs = {
        self,
        nixpkgs,
        nixpkgs-unstable,
    } @ flake-inputs: let
        system = "x86_64-linux";
        pkgs = nixpkgs.legacyPackages.${system};
    in {
        lib = import ./lib.nix nixpkgs.lib;

        nixosModules.default = self.nixosModules.nixos-core;
        nixosModules.nixos-core = import ./modules;

        overlays.default = self.overlays.unfree-unstable;
        overlays.unfree = import ./overlays/unfree.nix {inherit flake-inputs;};
        overlays.unstable = import ./overlays/unstable.nix {inherit flake-inputs;};
        overlays.unfree-unstable = import ./overlays/unfree-unstable.nix {inherit flake-inputs;};

        packages.${system} = {
            install = pkgs.callPackage ./installer/install {
                alejandra = pkgs.callPackage ./packages/alejandra.nix {};
            };
            nixos-iso = self.nixosConfigurations.nixos-iso.config.system.build.isoImage;
        };

        nixosConfigurations.nixos-iso = nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = {
                inherit flake-inputs;
                inherit (self.packages.${system}) install;
            };
            modules = [./installer/nixos-iso.nix];
        };
    };
}
