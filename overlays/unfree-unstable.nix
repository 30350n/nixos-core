{flake-inputs}: final: prev: {
    unfree = import flake-inputs.nixpkgs {
        inherit (final) system;
        config.allowUnfree = true;
    };
    unstable =
        import flake-inputs.nixpkgs-unstable {
            inherit (final) system;
        }
        // {
            unfree = import flake-inputs.nixpkgs-unstable {
                inherit (final) system;
                config.allowUnfree = true;
            };
        };
}
