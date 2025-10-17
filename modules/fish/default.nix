{
    config,
    lib,
    pkgs,
    ...
}: {
    options.nixos-core.fish = {
        enable = lib.mkEnableOption "fish" // {default = true;};
        loginShell = {
            enable = lib.mkEnableOption "loginShell" // {default = true;};
            skipParents = lib.mkOption {
                type = lib.types.listOf lib.types.string;
                default = [];
            };
        };
    };

    config = lib.mkIf config.nixos-core.fish.enable (lib.mkMerge [
        {
            programs.fish = {
                enable = true;

                shellAliases = {
                    cat = "bat";
                    ls = "eza -l";
                    la = "eza -la";
                    laa = "eza -laa";
                };

                shellInit = import ./tide.nix;

                interactiveShellInit = ''
                    functions --erase l ll

                    set fish_greeting

                    set _make_sparse_prompt false
                    function _sparse_prompt --on-event=fish_prompt
                        if test "$_make_sparse_prompt" = true
                            echo
                        else
                            set _make_sparse_prompt true
                        end
                    end

                    function clear --wraps=clear
                        set _make_sparse_prompt false
                        command clear $argv
                    end
                '';
            };

            documentation.man.generateCaches = false;

            environment.systemPackages = [pkgs.fishPlugins.tide];
            environment.variables.SHELL = "${config.programs.fish.package}/bin/fish";

            #xdg.desktopEntries.fish = {
            #    name = "fish";
            #    noDisplay = true;
            #};
        }
        (lib.mkIf config.nixos-core.fish.loginShell.enable {
            programs.bash.interactiveShellInit = let
                extraSkipParents =
                    lib.strings.concatMapStringsSep " && " (cmd: "$_parent != \"${cmd}\"")
                    config.nixos-core.fish.loginShell.skipParents;
            in ''
                _parent=$(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm)
                if [[ $_parent != "fish" && ${extraSkipParents} && -z "$BASH_EXECUTION_STRING" ]]
                then
                    unset _parent
                    shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
                    exec ${config.programs.fish.package}/bin/fish $LOGIN_OPTION
                fi
                unset _parent
            '';
        })
    ]);
}
