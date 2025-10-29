{flake-inputs}: final: prev: let
    system = final.stdenv.hostPlatform.system;
in {
    unfree = import flake-inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
    };
    unstable =
        import flake-inputs.nixpkgs-unstable {
            inherit system;
        }
        // {
            unfree = import flake-inputs.nixpkgs-unstable {
                inherit system;
                config.allowUnfree = true;
            };
        };
}
