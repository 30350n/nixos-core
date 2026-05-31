{
    fetchpatch,
    tide,
}:
tide.overrideAttrs (prevAttrs: {
    patches =
        (prevAttrs.patches or [])
        ++ [
            ./status-display-variable.patch
            ./icon-after-status.patch
            (fetchpatch {
                url = "https://patch-diff.githubusercontent.com/raw/IlanCosman/tide/pull/619.patch";
                sha256 = "TV3/rLMCccToJKxjHt0ewdkoKa3I6gUspF83FYb1Q4s=";
            })
        ];
})
