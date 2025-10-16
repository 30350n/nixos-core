{
    config,
    lib,
    pkgs,
    ...
}: let
    self = config.nixos-core.cockpit;
in {
    options.nixos-core.cockpit = {
        enable = lib.mkEnableOption "cockpit" // {default = true;};
        openFirewall = lib.mkEnableOption "openFirewall";
        desktopItem = lib.mkEnableOption "desktopItem" // {default = !self.openFirewall;};
    };

    config = lib.mkMerge [
        (lib.mkIf self.enable {
            services.cockpit = {
                enable = true;
                openFirewall = self.openFirewall;
                allowed-origins = let
                    port = builtins.toString config.services.cockpit.port;
                in [
                    "http://localhost:${port}"
                ];
            };
        })
        (lib.mkIf self.desktopItem {
            environment.systemPackages = [
                (
                    pkgs.makeDesktopItem {
                        name = "cockpit-desktop-item";
                        desktopName = "Cockpit";
                        icon = pkgs.fetchurl {
                            url =
                                "https://raw.githubusercontent.com/cockpit-project/cockpit/"
                                + "d32340cd69824da5dd27549a4eed889d1d83b3c5/pkg/shell/images/"
                                + "cockpit-icon.svg";
                            sha256 = "phAGG4nPNVVKLk2DMlVnLz7iQkOaRobIutHqKhrHFzQ=";
                        };
                        exec = "${pkgs.chromium}/bin/chromium --app=http://localhost:9090";
                    }
                )
            ];
        })
    ];
}
