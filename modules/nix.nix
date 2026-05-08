{
    fast-nix-gc,
    nixpkgs,
    nixpkgs-unstable,
    ...
}: {
    imports = [
        fast-nix-gc.nixosModules.default
    ];

    services.fast-nix-gc = {
        enable = true;
        automatic = true;
        deleteOlderThan = "14d";
    };

    services.fast-nix-optimise = {
        enable = true;
        automatic = true;
    };

    nix.registry.unstable = {
        from = {
            type = "indirect";
            id = "unstable";
        };
        flake = nixpkgs-unstable;
    };

    nix.nixPath = [
        "nixpkgs=${nixpkgs.outPath}"
        "unstable=${nixpkgs-unstable.outPath}"
    ];

    nix.settings.experimental-features = ["nix-command" "flakes"];
}
