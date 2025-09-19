{
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    };

    outputs = {self}: {
        nixosModules.default = self.nixosModules.nixos-core;
        nixosModules.nixos-core = ./modules;
    };
}
