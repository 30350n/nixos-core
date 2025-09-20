{pkgs, ...}: {
    programs = {
        bash.promptInit = ''
            PROMPT_COMMAND='GIT_PS1_CMD=$(__git_ps1 " (%s)")'
            if [[ $(id -u) == 0 ]]; then
                PS1='\n\w\[\e[33;1m\]''${GIT_PS1_CMD}\n\[\e[31;1m\]$\[\e[0m\] '
            else
                PS1='\n\w\[\e[33;1m\]''${GIT_PS1_CMD}\n\[\e[32;1m\]$\[\e[0m\] '
            fi
        '';

        command-not-found.enable = false;

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

        nix-ld.enable = true;
    };

    environment.systemPackages = with pkgs; [
        alejandra
        jujutsu
        nixos-core.configure
        nixos-core.rebuild

        bat
        eza
        htop
        nix-output-monitor
        zoxide
    ];
}
