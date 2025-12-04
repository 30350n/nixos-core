{flake-inputs, ...}: {
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
        flake = flake-inputs.nixpkgs-unstable;
    };

    nix.nixPath = [
        "nixpkgs=${flake-inputs.nixpkgs.outPath}"
        "unstable=${flake-inputs.nixpkgs-unstable.outPath}"
    ];

    nix.settings.experimental-features = ["nix-command" "flakes"];
}
