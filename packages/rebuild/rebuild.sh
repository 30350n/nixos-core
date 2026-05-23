#!/usr/bin/env bash

help="\
Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS]

Options:
  -d, --dry            Rebuild configuration without activating it.
  -u, --update         Update the flake before rebuilding.
  -r, --remote <host>  Build configuration for remote host.
  -h, --help           Show this message and exit.
"

info() {
    echo -e "\033[94m$1\033[0m"
}
hint() {
    echo -e "\033[2;3m$1\033[0m"
}
success() {
    echo -e "\033[92m$1\033[0m"
}
warning() {
    echo -e "\033[93m$1\033[0m"
}
error() {
    echo -e "\033[91m$1\033[0m"
}

unexpected_error() {
    error "Unexpected error on line $1 (code $2)"
}
trap 'unexpected_error $LINENO $?' ERR

check_option_value() {
    if [[ -z ${1-} || $1 == -* ]]; then
        echo "$help"
        exit 1
    fi
}

command="switch"
update=false
config=""
remote_host=""
extra_args=()

while [[ $OPTIND -le $# ]]; do
    if getopts ":-:" OPTCHAR; then
        if [[ $OPTCHAR == "-" ]]; then
            case "$OPTARG" in
                dry)
                    command="dry-activate"
                    ;;
                update)
                    update=true
                    ;;
                remote)
                    check_option_value ${!OPTIND-}
                    remote_host=${!OPTIND}
                    ((OPTIND++))
                    ;;
                help)
                    echo "$help"
                    exit 0
                    ;;
                *)
                    warning "warning: invalid argument '--$OPTARG'"
                    ;;
            esac
        else
            case "$OPTARG" in
                d)
                    command="dry-activate"
                    ;;
                u)
                    update=true
                    ;;
                r)
                    check_option_value ${!OPTIND-}
                    remote_host=${!OPTIND}
                    ((OPTIND++))
                    ;;
                h)
                    echo "$help"
                    exit 0
                    ;;
                *)
                    warning "warning: invalid argument '-$OPTARG'"
                    ;;
            esac
        fi
    fi
done

if [[ -z $remote_host ]]; then
    if [[ $(id -u) != 0 ]]; then
        sudo rebuild || exit $?
        exit 0
    fi

    pushd /etc/nixos &> /dev/null || (error "'/etc/nixos' does not exist" && exit 1)
fi

if [[ -d ./nixos-core ]]; then
    extra_args+=(--override-input nixos-core path:./nixos-core)
elif [[ -d ./core ]]; then
    extra_args+=(--override-input nixos-core path:./core)
fi

if [[ -n $remote_host ]]; then
    extra_args+=(--target-host "root@$remote_host")
    config="#${remote_host%%.*}"
fi

if $update; then
    info "Updating NixOS configuration ..."
    nix flake update
else
    info "Updating 'nixos-core' flake input ..."
    nix flake update nixos-core
fi

if [[ -f ".pre-commit-config.yaml" ]]; then
    info "Autoformatting NixOS configuration ..."
    pre-commit run --all-files &> /dev/null || true
    pre-commit run --all-files | (grep -v "Passed" || true)
fi

echo
info "Configuration changes:"
changed_files=$(jj diff --summary --color always 2> /dev/null)
if [[ $(wc -l <<< "$changed_files") -le 5 ]]; then
    jj diff --no-pager 2> /dev/null
else
    echo "$changed_files"
fi

echo
info "Building NixOS configuration ..."
nixos-rebuild $command --flake "path:.${config}" "${extra_args[@]}" --log-format internal-json -v |&
    tee >(
        awk '
            BEGIN { cmd = "jq --unbuffered --raw-output '\''select(.action == \"msg\").msg'\''" }
            /^@nix / {
                gsub(/^@nix /, "")
                gsub(/\\u001b\[[0-9;]*m/, "")
                print | cmd
                next
            }
            { print }
            END { close(cmd) }
        ' > rebuild.log
    ) |&
    nom --json ||
    {
        error "Build failed with code $?"
        failed_service=$(
            grep "the following units failed: " rebuild.log |
                grep -oP 'home-manager-[^ ]+\.service' || true
        )
        if [[ -n $failed_service ]]; then
            error "Activating home-manager failed with:"
            line=$(
                journalctl --unit "$failed_service" | grep -n "Starting Home Manager environment" |
                    tail -n1 | cut -d: -f1
            )
            SYSTEMD_COLORS=true journalctl --unit "$failed_service" | tail -n "+$line"
        fi
        hint "(check $PWD/rebuild.log for the full build log)"
        popd &> /dev/null || true
        exit 1
    }

run_on_target=""
if [[ -n $remote_host ]]; then
    run_on_target="ssh root@$remote_host"
    nix build ".#nixosConfigurations.${remote_host%%.*}.config.system.build.toplevel" \
        --out-link "system-${remote_host%%.*}" &> /dev/null
fi

NIX_SYSTEM="/nix/var/nix/profiles/system"
generation_number=$($run_on_target readlink "$NIX_SYSTEM" | awk -F "-" '{print $2}')
generation_date=$(
    $run_on_target stat --format %W -L $NIX_SYSTEM | jq -r 'strflocaltime("%Y-%m-%d %H:%M:%S")'
)
generation_nixos_version=$($run_on_target cat $NIX_SYSTEM/nixos-version)

generation_prefix="$($run_on_target hostname) - Generation "
commit_message=$(
    jj show --summary 2> /dev/null | grep -e "^    " -e '^$' | tail -n +2 | head -n -1 | cut -c 5- |
        grep -v "^$generation_prefix" | grep -v '^(no description set)$' || true
)
generation="$generation_number $generation_date $generation_nixos_version"
echo -e "$commit_message\n\n$generation_prefix$generation" | jj describe --stdin &> /dev/null

success "Successfully built NixOS configuration!"
hint "($generation_prefix$generation)"
popd &> /dev/null || true
