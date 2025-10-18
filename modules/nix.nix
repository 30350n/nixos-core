{flake-inputs, ...}: {
    nix.gc = {
        automatic = true;
        persistent = true;
        dates = "Sat *-*-* 08:00";
        options = "--delete-older-than 14d";
    };

    nix.optimise = {
        automatic = true;
        persistent = true;
        dates = ["09:00"];
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
