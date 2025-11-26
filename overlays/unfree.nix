{nixpkgs, ...}: final: prev: {
    unfree = import nixpkgs {
        inherit (final.stdenv.hostPlatform) system;
        config.allowUnfree = true;
    };
}
