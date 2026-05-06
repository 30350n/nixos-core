{
    chromium,
    inkscape,
    lib,
    makeDesktopItem,
    runCommand,
    symlinkJoin,
    writeShellScriptBin,
}: {
    url,
    name,
    app_id ? lib.toLower (builtins.replaceStrings [" "] ["_"] name),
    icon ? null,
    icon-scale ? null,
    preRun ? "",
    extraArgs ? "",
    comment ? null,
    categories ? [],
}:
symlinkJoin rec {
    inherit name;
    paths = let
        script = writeShellScriptBin app_id ''
            ${preRun}
            ${chromium}/bin/chromium \
                --app=http://${url} \
                --user-data-dir="$XDG_CONFIG_HOME/pwa-${app_id}" \
                --profile-directory=${app_id} \
                ${extraArgs}
        '';
    in [
        script
        (makeDesktopItem {
            exec = "${script}/bin/${app_id}";
            desktopName = name;
            name = let
                base_url =
                    builtins.elemAt (builtins.match "([^:/]+://)?([^:/]+)(:[0-9]+)?(/.*)?" url) 1;
            in "chrome-${base_url}__-${app_id}";
            icon =
                if icon == null || icon-scale == null
                then icon
                else
                    runCommand (baseNameOf icon) {} ''
                        ${inkscape}/bin/inkscape "${icon}" \
                            --actions "select-all;transform-scale:${toString icon-scale}; \
                                export-filename:$out;export-do"
                    '';
            inherit comment categories;
        })
    ];
}
