{
    nixpkgs,
    nixpkgs-unstable,
    ...
}: {
    nix.gc = {
        automatic = true;
        persistent = true;
        options = "--delete-older-than 14d";
    };

    nix.optimise = {
        automatic = true;
        persistent = true;
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
