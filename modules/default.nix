{
    config,
    lib,
    ...
}: {
    imports = (
        lib.filter
        (file: lib.strings.hasSuffix ".nix" file && file != ./default.nix)
        (lib.filesystem.listFilesRecursive ./.)
    );

    options.nixos-core = {
        allowUnfree = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
        };
    };

    config = {
        nixpkgs.overlays = [(import ../packages)];
        nixpkgs.config.allowUnfreePredicate = package:
            builtins.elem (lib.getName package) config.nixos-core.allowUnfree;
    };
}
