{flake-inputs}: final: prev: {
    unfree = import flake-inputs.nixpkgs {
        inherit (final.stdenv.hostPlatform) system;
        config.allowUnfree = true;
    };
}
