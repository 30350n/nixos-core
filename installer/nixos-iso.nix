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

    environment.systemPackages = [install];
}
