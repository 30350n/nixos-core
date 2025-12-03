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
                (pkgs.nixos-core.makeWebApp {
                    url = "localhost:9090";
                    name = "Cockpit";
                    icon = "${pkgs.cockpit.src}/pkg/shell/images/cockpit-icon.svg";
                })
            ];
        })
    ];
}
