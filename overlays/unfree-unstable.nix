{
    nixpkgs,
    nixpkgs-unstable,
    ...
}: final: prev: let
    system = final.stdenv.hostPlatform.system;
in {
    unfree = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
    };
    unstable =
        import nixpkgs-unstable {
            inherit system;
        }
        // {
            unfree = import nixpkgs-unstable {
                inherit system;
                config.allowUnfree = true;
            };
        };
}
