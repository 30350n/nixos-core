{flake-inputs}: final: prev: {
    unfree = import flake-inputs.nixpkgs {
        inherit (final) system;
        config.allowUnfree = true;
    };
}
