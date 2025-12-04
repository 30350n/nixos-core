{
    chromium,
    inkscape,
    makeDesktopItem,
    runCommand,
}: {
    url,
    name,
    icon ? null,
    icon-scale ? null,
}:
makeDesktopItem {
    exec = "${chromium}/bin/chromium --app=http://${url}";
    desktopName = name;
    name = let
        base_url = builtins.elemAt (builtins.match "([^:/]+://)?([^:/]+)(:[0-9]+)?(/.*)?" url) 1;
    in "chrome-${base_url}__-Default";
    icon =
        if icon == null || icon-scale == null
        then icon
        else
            runCommand (baseNameOf icon) {} ''
                ${inkscape}/bin/inkscape "${icon}" \
                    --actions "select-all;transform-scale:${toString icon-scale}; \
                        export-filename:$out;export-do"
            '';
}
