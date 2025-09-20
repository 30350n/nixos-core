{
    alejandra,
    makeWrapper,
    symlinkJoin,
    writeText,
}:
symlinkJoin {
    name = "alejandra";
    paths = [alejandra];
    buildInputs = [makeWrapper];
    postBuild = let
        config = writeText "alejandra.toml" ''
            indentation = "FourSpaces"
        '';
    in ''
        wrapProgram $out/bin/alejandra --add-flags "--experimental-config ${config}"
    '';
}
