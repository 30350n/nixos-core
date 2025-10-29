{flake-inputs}: final: prev: {
    unstable = import flake-inputs.nixpkgs-unstable {
        inherit (final.stdenv.hostPlatform) system;
    };
}
