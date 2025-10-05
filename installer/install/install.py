import re
import shutil
import subprocess
from argparse import ArgumentParser
from getpass import getpass
from hashlib import md5
from pathlib import Path
from typing import Any, cast

from cutie import prompt_yes_or_no, select, select_multiple
from error_helper import error, hint, info, prompt, prompt_input, success, warning

INSTALL_PATH = Path("/mnt")
INSTALL_CONFIG_PATH = INSTALL_PATH / "persist" / "etc" / "nixos"
INSTALL_PASSWORDS_PATH = INSTALL_PATH / "persist" / "passwords"

TEMP_CONFIG_PATH = Path("/tmp/nixos")
TEMP_CONFIG_HOSTS_PATH = TEMP_CONFIG_PATH / "hosts"


def install(config_url: str, dry_run=False):
    info(f"Installing NixOS configuration from {config_url}")
    print()

    info("Cloning configuration ...")
    shutil.rmtree(TEMP_CONFIG_PATH, ignore_errors=True)
    TEMP_CONFIG_PATH.mkdir(parents=True)
    run(["git", "clone", config_url, str(TEMP_CONFIG_PATH)])
    run(["jj", "git", "init", "--colocate", str(TEMP_CONFIG_PATH)], silent=True)
    print()

    if not (hosts := [host_dir.name for host_dir in TEMP_CONFIG_HOSTS_PATH.glob("*/")]):
        return error(f"failed to find host configurations in {TEMP_CONFIG_HOSTS_PATH}")

    if len(hosts) == 1:
        host = hosts[0]
        info(f"Auto-selected host configuration '{host}'")
    else:
        info("Detected multiple host configurations")
        prompt("select the host configuration you want to install", prefix="")
        host = hosts[select(hosts, **SELECT_KWARGS)]
        print()

    hardware_config_nix = TEMP_CONFIG_HOSTS_PATH / host / "hardware-configuration.nix"
    if not hardware_config_nix.is_file():
        info(f"Generating '{hardware_config_nix.name}' for host '{host}' ...")
        hardware_config = run("nixos-generate-config --show-hardware-config", capture=True).stdout
        hardware_config = CLEANUP_HARDWARE_CONFIG_REGEX.sub("", hardware_config)
        hardware_config: str = run("alejandra", input=hardware_config, capture=True).stdout
        hardware_config_nix.write_text(hardware_config)

    disko_nix = TEMP_CONFIG_HOSTS_PATH / host / "disko.nix"
    disko_parsed = run(["nix-instantiate", "--parse", str(disko_nix)], capture=True)
    required_devices = [
        match.group(1) for match in DISKO_DEVICES_REGEX.finditer(disko_parsed.stdout)
    ]
    if not required_devices:
        return error(
            f"host configuration '{host}' does not specify any physical devices\n"
            f"(make sure '{disko_nix.relative_to(TEMP_CONFIG_PATH)}' has a 'devices' argument)"
        )
    info(
        f"Host configuration '{host}' requires {len(required_devices)} physical "
        f"device{'s' if len(required_devices) > 1 else ''} [{' '.join(required_devices)}]"
    )

    block_devices: list[str] = (
        run("lsblk -I 8,259 -nd -o NAME", capture=True).stdout.strip().split()
    )
    if len(required_devices) > len(block_devices):
        return error(
            f"host configuration '{host}' requires {len(required_devices)} physical devices but "
            f"only {len(block_devices)} are available"
        )

    available_devices: list[tuple[str, str]] = []
    for blk_device in block_devices:
        udevadm_info = run(["udevadm", "info", "-q", "symlink", "--name", blk_device], capture=True)
        symlinks = sorted(
            (
                link
                for link in udevadm_info.stdout.strip().split()
                if link.startswith("disk/by-id/") and not link.startswith("disk/by-id/nvme-eui.")
            )
        )
        available_devices.append((blk_device, symlinks[0]))

    devices: dict[str, tuple[str, str]] = {}
    for device in required_devices:
        prompt(f"select the physical device for '{device}'", prefix="")
        index = select(
            [f"{blk} ({link.split('disk/by-id/')[-1]})" for blk, link in available_devices],
            **SELECT_KWARGS,
        )
        devices[device] = available_devices.pop(index)
        print()

    blk_devices_str = " ".join((f"/dev/{blk_device}" for blk_device, _ in devices.values()))
    warning(f"ALL DATA ON {blk_devices_str} WILL BE ERASED.", prefix="WARNING: ")
    if not prompt_yes_or_no("continue?", deselected_prefix="  ", selected_prefix="> "):
        return
    print()

    devices_arg = f"{{ {' '.join((f'{dev} = "/dev/{id}";' for dev, (_, id) in devices.items()))} }}"
    info("Formatting devices with disko ...")
    run([*DISKO_FORMAT, str(disko_nix), "--arg", "devices", devices_arg], silent=True, dry=dry_run)

    devices_file = TEMP_CONFIG_HOSTS_PATH / host / "devices.nix"
    devices_file_content = (
        f"{{\n{''.join((f'    {dev} = "/dev/{id}";\n' for dev, (_, id) in devices.items()))}}}\n"
    )
    devices_file.write_text(devices_file_content)

    host_id_file = TEMP_CONFIG_HOSTS_PATH / host / "host-id.nix"
    serial_numbers = [
        run(["lsblk", "-nd", "-o", "serial", f"/dev/{blk_device}"], capture=True).stdout
        for blk_device, _ in devices.values()
    ]
    host_id = md5("".join(serial_numbers).encode()).hexdigest()[:8]
    host_id_file.write_text(f'"{host_id}"\n')

    if INSTALL_CONFIG_PATH.exists():
        return error(f"{INSTALL_CONFIG_PATH} exists")

    INSTALL_CONFIG_PATH.parent.mkdir(parents=True)
    shutil.move(TEMP_CONFIG_PATH, INSTALL_CONFIG_PATH)
    print()

    devices_file = INSTALL_CONFIG_PATH / devices_file.relative_to(TEMP_CONFIG_PATH)
    host_id_file = INSTALL_CONFIG_PATH / host_id_file.relative_to(TEMP_CONFIG_PATH)
    run(["chattr", "+i", str(devices_file), str(host_id_file)], dry=dry_run)

    info("Installing NixOS ...")
    run([*NIXOS_INSTALL, "--flake", f"path:{INSTALL_CONFIG_PATH}#{host}"], silent=True, dry=dry_run)
    print()

    passwd = ((Path("/") if dry_run else INSTALL_PATH) / "etc" / "passwd").read_text()
    users_dict = {
        user: int(id)
        for user, _, id, *_, login_shell in map(lambda line: line.split(":"), passwd.splitlines())
        if not login_shell.endswith("/bin/nologin")
    }
    users, user_ids = cast(tuple[list[str], list[int]], tuple(zip(*users_dict.items())))

    info("Setup user passwords")
    INSTALL_PASSWORDS_PATH.mkdir(parents=True)
    for user in users:
        while True:
            password = getpass(f"password for {user}: ")
            retyped = getpass(f"retype password for {user}: ")
            if password == retyped:
                break
            error("passwords do not match", prefix="", end="\n\n")

        hashed_password = run(["mkpasswd", password], capture=True).stdout.strip()
        (INSTALL_PASSWORDS_PATH / user).write_text(hashed_password)
        print()

    info("Add authorized ssh key")
    prompt("select users to add authorized ssh key to")
    selected_users = select_multiple(users, **SELECT_MULTIPLE_KWARGS)
    print()

    if selected_users:
        while not (ssh_key := prompt_input("ssh \033[1mpublic\033[0m key").strip()):
            pass
        (home := INSTALL_PATH / "home").mkdir(mode=0o755)
        for user, user_id in map(lambda i: (users[i], user_ids[i]), selected_users):
            (user_home := INSTALL_PATH / "root" if user_id == 0 else home / user).mkdir(mode=0o700)
            (ssh_dir := user_home / ".ssh").mkdir(mode=0o700)
            authorized_keys = ssh_dir / "authorized_keys"
            authorized_keys.write_text(f"{ssh_key}\n")
            authorized_keys.chmod(mode=0o600)

            for path in [authorized_keys, ssh_dir, user_home]:
                shutil.chown(path, user_id)

    success("Successfully installed NixOS!", prefix="")
    hint("reboot now to finish installation")


DISKO_DEVICES_REGEX = re.compile(r"device\s+=\s+\(devices\)\.(\w+)")
CLEANUP_HARDWARE_CONFIG_REGEX = re.compile(r"#.*|fileSystems\.[^=]*=\s*{[^}]*};")

SELECT_KWARGS: dict[str, Any] = dict(deselected_prefix="  ", selected_prefix="> ")
SELECT_MULTIPLE_KWARGS: dict[str, Any] = dict(
    deselected_unticked_prefix="  [ ] ",
    deselected_ticked_prefix="  [x] ",
    selected_unticked_prefix="> [ ] ",
    selected_ticked_prefix="> [x] ",
)

DISKO_FORMAT = [
    "nix",
    "--quiet",
    "--experimental-features",
    "nix-command flakes",
    "run",
    "github:nix-community/disko",
    "--",
    "--mode",
    "destroy,format,mount",
    "--yes-wipe-all-disks",
]

NIXOS_INSTALL = ["nixos-install", "--no-root-passwd", "--root", str(INSTALL_PATH)]


def run(
    command: str | list[str],
    *,
    input=None,
    check=True,
    silent=False,
    capture=False,
    dry=False,
) -> subprocess.CompletedProcess[Any]:
    if isinstance(command, str):
        command = command.split()

    if dry:
        assert not capture
        command = " ".join(command)
        info(f"[dry] would run '{command}'")
        return cast(subprocess.CompletedProcess, object())

    return subprocess.run(
        command,
        input=input,
        check=check,
        capture_output=capture,
        text=True,
        **(SILENT if silent and not capture else {}),
    )


SILENT: dict[str, Any] = dict(stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    parser = ArgumentParser()
    parser.add_argument("config_url", metavar="nixos-config-url")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    install(**args.__dict__)


if __name__ == "__main__":
    main()
