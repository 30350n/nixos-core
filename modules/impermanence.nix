{
    config,
    lib,
    ...
}: {
    options.nixos-core.impermanence = {
        enable = lib.mkEnableOption "impermanence";
        persistFileSystem = lib.mkOption {type = lib.types.str;};
        persist = {
            directories = lib.mkOption {
                type = lib.types.listOf (lib.types.either lib.types.str lib.types.attrs);
                default = [];
            };
            files = lib.mkOption {
                type = lib.types.listOf (lib.types.either lib.types.str lib.types.attrs);
                default = [];
            };
        };
        resetCommands = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
        };
    };

    config = let
        cfg = config.nixos-core.impermanence;
    in
        lib.mkIf cfg.enable (lib.mkMerge [
            {
                fileSystems.${cfg.persistFileSystem}.neededForBoot = true;

                environment.persistence.${cfg.persistFileSystem} = {
                    directories =
                        [
                            "/etc/nixos"
                            "/var/lib/bluetooth"
                            "/var/lib/nixos"
                            "/var/lib/systemd/coredump"
                            "/var/lib/systemd/timers"
                            "/var/log"
                            "/root/.ssh"
                        ]
                        ++ cfg.persist.directories
                        ++ (
                            lib.optional config.networking.networkmanager.enable
                            "/etc/NetworkManager/system-connections"
                        )
                        ++ (lib.optional config.programs.fish.enable "/root/.local/share/fish")
                        ++ (lib.optional config.programs.zoxide.enable "/root/.local/share/zoxide");
                    files =
                        [
                            "/etc/machine-id"
                            "/etc/ssh/ssh_host_ed25519_key"
                            "/etc/ssh/ssh_host_ed25519_key.pub"
                            "/etc/ssh/ssh_host_rsa_key"
                            "/etc/ssh/ssh_host_rsa_key.pub"
                        ]
                        ++ cfg.persist.files;
                };
            }
            (lib.mkIf (cfg.resetCommands != null) {
                boot.initrd.systemd = {
                    enable = true;
                    services.impermanence-reset-filesystem = {
                        wantedBy = ["initrd.target"];
                        before = ["sysroot.mount"];
                        after = [
                            "initrd-root-device.target"
                            "zfs-import.target"
                            "local-fs-pre.target"
                        ];
                        unitConfig.DefaultDependencies = false;
                        serviceConfig.Type = "oneshot";
                        script = ''
                            echo "resetting '${cfg.persistFileSystem}' file system" > /dev/kmsg
                            {
                                ${cfg.resetCommands}
                            } > /dev/kmsg 2>&1 || true
                        '';
                    };
                };
            })
        ]);
}
