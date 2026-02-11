final: prev: rec {
    nixos-core = {
        configure = final.callPackage ./configure.nix {};
        rebuild = final.callPackage ./rebuild {inherit alejandra nix-output-monitor;};

        makeWebApp = final.callPackage ./makeWebApp.nix {};
    };

    alejandra = final.callPackage ./alejandra.nix {inherit (prev) alejandra;};
    fishPlugins =
        prev.fishPlugins
        // {
            tide = import ./tide {inherit (prev.fishPlugins) tide;};
            zoxide-fish = final.callPackage ./zoxide-fish.nix {};
        };
    nix-output-monitor = import ./nix-output-monitor {inherit (prev) nix-output-monitor;};
}
