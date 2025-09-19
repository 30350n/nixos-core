{lib, ...}: {
    imports = (
        lib.filter
        (file: lib.strings.hasSuffix ".nix" file && file != ./default.nix)
        (lib.filesystem.listFilesRecursive ./.)
    );
}
