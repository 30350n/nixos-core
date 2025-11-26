{nixpkgs-unstable, ...}: final: prev: {
    unstable = import nixpkgs-unstable {
        inherit (final.stdenv.hostPlatform) system;
    };
}
