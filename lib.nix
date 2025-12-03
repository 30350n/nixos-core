lib:
lib.extend (final: prev: {
    nixos-core.autoImport = path: (builtins.filter final.pathExists (final.mapAttrsToList (
        file: type:
            if type == "directory"
            then path + "/${file}/default.nix"
            else path + "/${file}"
    )
    (final.filterAttrs (file: _: file != "default.nix") (builtins.readDir path))));
})
