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

    users.users.nixos.password = "";
    services.openssh = {
        enable = true;
        settings.PermitEmptyPasswords = true;
    };
    security.pam.services.sshd.allowNullPassword = true;

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
