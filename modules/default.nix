{nix-index-database, ...}: {
    config,
    lib,
    pkgs,
    ...
}: {
    imports =
        [nix-index-database.nixosModules.nix-index]
        ++ (lib.nixos-core or (import ../lib.nix lib).nixos-core).autoImport ./.;

    options.nixos-core = {
        allowUnfree = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
        };
        normalUserGroups = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
        };
    };

    config = {
        documentation.nixos.enable = false;

        environment.systemPackages = with pkgs; [
            alejandra
            jujutsu
            nixos-core.configure
            nixos-core.rebuild

            bat
            eza
            htop
            nix-output-monitor
            unzip
            zip
        ];

        environment.variables.PAGER = "less -FrX";

        nixpkgs.overlays = [(import ../packages)];
        nixpkgs.config.allowUnfreePredicate = package:
            builtins.elem (lib.getName package) config.nixos-core.allowUnfree;

        programs = {
            bash.promptInit = ''
                PROMPT_COMMAND='GIT_PS1_CMD=$(__git_ps1 " (%s)")'
                if [[ $(id -u) == 0 ]]; then
                    PS1='\n\w\[\e[33;1m\]''${GIT_PS1_CMD}\n\[\e[31;1m\]$\[\e[0m\] '
                else
                    PS1='\n\w\[\e[33;1m\]''${GIT_PS1_CMD}\n\[\e[32;1m\]$\[\e[0m\] '
                fi
            '';

            git = {
                enable = true;
                lfs.enable = true;
                prompt.enable = true;
            };

            nano = {
                enable = true;
                nanorc = ''
                    set autoindent
                    set linenumbers
                    set tabsize 4
                    set whitespace "→·"
                '';
            };

            nix-index-database.comma.enable = true;

            nix-ld.enable = true;

            zoxide = {
                enable = true;
                flags = ["--cmd cd"];
            };
        };

        security.sudo.extraConfig = ''
            Defaults lecture = never
            Defaults env_keep += "EDITOR"
        '';

        users.groups = let
            normalUsers = map (user: user.name) (
                builtins.filter (user: user.isNormalUser) (builtins.attrValues config.users.users)
            );
        in
            lib.mkMerge (
                map (group: {${group}.members = normalUsers;}) config.nixos-core.normalUserGroups
            );
    };
}
