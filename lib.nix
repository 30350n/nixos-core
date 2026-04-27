lib:
lib.extend (final: prev: {
    nixos-core.autoImport = directory: (
        builtins.filter (file: final.pathExists file && lib.hasSuffix ".nix" file) (
            final.mapAttrsToList (
                file: type:
                    if type == "directory"
                    then directory + "/${file}/default.nix"
                    else directory + "/${file}"
            )
            (final.filterAttrs (file: _: file != "default.nix") (builtins.readDir directory))
        )
    );
})
