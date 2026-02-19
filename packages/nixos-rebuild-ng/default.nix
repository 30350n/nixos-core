{nixos-rebuild-ng}:
nixos-rebuild-ng.overrideAttrs (prevAttrs: {
    patches = (prevAttrs.patches or []) ++ [./no-tracebacks.patch];
})
