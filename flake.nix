{
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
        nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    };

    outputs = {
        self,
        nixpkgs,
        nixpkgs-unstable,
    } @ flake-inputs: {
        nixosModules.default = self.nixosModules.nixos-core;
        nixosModules.nixos-core = import ./modules;

        overlays.default = self.overlays.unfree-unstable;
        overlays.unfree = import ./overlays/unfree.nix {inherit flake-inputs;};
        overlays.unfree-unstable = import ./overlays/unfree-unstable.nix {inherit flake-inputs;};
        overlays.unstable = import ./overlays/unstable.nix {inherit flake-inputs;};
    };
}
