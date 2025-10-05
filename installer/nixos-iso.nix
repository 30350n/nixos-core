{
    install,
    modulesPath,
    ...
}: {
    imports = [
        (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
        ../modules
    ];

    networking.hostName = "nixos-iso";

    services.openssh = {
        enable = true;
        extraConfig = ''
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
            workstation = true;
        };
    };

    environment.systemPackages = [install];
}
