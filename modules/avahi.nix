{
    config,
    lib,
    ...
}: {
    services.avahi = {
        enable = true;
        nssmdns4 = true;
        publish = let
            publish = config.services.avahi.publish.enable;
        in {
            enable = lib.mkDefault true;
            addresses = lib.mkDefault publish;
            domain = lib.mkDefault publish;
            hinfo = lib.mkDefault publish;
            userServices = lib.mkDefault publish;
            workstation = lib.mkDefault publish;
        };
    };
}
