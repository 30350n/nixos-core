{
    install,
    modulesPath,
    ...
}: {
    imports = [
        (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
        ../modules
    ];

    isoImage.edition = "core";
    networking.hostName = "nixos-iso";

    services.openssh = {
        enable = true;
        extraConfig = ''
            UsePAM no
            PermitEmptyPasswords yes
        '';
    };

    services.avahi = {
        enable = true;
        nssmdns4 = true;
        publish = {
            enable = true;
            addresses = true;
            domain = true;
            hinfo = true;
            userServices = true;
            workstation = true;
        };
    };

    environment.systemPackages = [install];
}
