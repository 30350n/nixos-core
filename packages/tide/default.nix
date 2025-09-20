{tide}:
tide.overrideAttrs (prevAttrs: {
    patches =
        (prevAttrs.patches or [])
        ++ [
            ./status-display-variable.patch
            ./icon-after-status.patch
        ];
})
