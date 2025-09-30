import re
import shutil
import subprocess
from argparse import ArgumentParser
from getpass import getpass
from hashlib import md5
from pathlib import Path
from typing import Any, cast

from cutie import prompt_yes_or_no, select
from error_helper import error, hint, info, prompt, success, warning

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
    run("jj git init --colocate", silent=True)
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

    disko_nix = TEMP_CONFIG_HOSTS_PATH / host / "disko.nix"
    disko_parsed = run(["nix-instantiate", "--parse", str(disko_nix)], stdout=True)
    required_devices = [
        match.group(1) for match in DISKO_DEVICES_REGEX.finditer(disko_parsed.stdout.decode())
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
        run("lsblk -I 8,259 -nd -o NAME", stdout=True).stdout.decode().strip().split()
    )
    if len(required_devices) > len(block_devices):
        return error(
            f"host configuration '{host}' requires {len(required_devices)} physical devices but "
            f"only {len(block_devices)} are available"
        )

    available_devices: list[tuple[str, str]] = []
    for blk_device in block_devices:
        udevadm_info = run(["udevadm", "info", "-q", "symlink", "--name", blk_device], stdout=True)
        symlinks = sorted(
            (
                link
                for link in udevadm_info.stdout.decode().strip().split()
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

    devices_argstr = f"{{{', '.join((f'{dev}="/dev/{id}"' for dev, (_, id) in devices.items()))}}}"
    info("Formatting devices with disko ...")
    run([*DISKO_FORMAT, str(disko_nix), "--argstr", "devices", devices_argstr], dry=dry_run)

    devices_file = TEMP_CONFIG_HOSTS_PATH / host / "devices.nix"
    devices_file_content = (
        f"{{\n{''.join((f'    {dev} = "/dev/{id}",\n' for dev, (_, id) in devices.items()))}}}\n"
    )
    devices_file.write_text(devices_file_content)

    host_id_file = TEMP_CONFIG_HOSTS_PATH / host / "host-id.nix"
    serial_numbers = [
        run(["lsblk", "-nd", "-o", "serial", f"/dev/{blk_device}"], stdout=True).stdout
        for blk_device, _ in devices.values()
    ]
    host_id = md5(b"".join(serial_numbers)).hexdigest()[:8]
    host_id_file.write_text(f'"{host_id}"\n')

    run(["chattr", "+i", str(devices_file), str(host_id_file)], dry=dry_run)

    if INSTALL_PATH.exists() and (not INSTALL_PATH.is_dir() or any(INSTALL_PATH.glob("*"))):
        return error(f"{INSTALL_PATH} exists and is not an empty directory")

    if not dry_run:
        INSTALL_CONFIG_PATH.parent.mkdir(parents=True)
        shutil.move(TEMP_CONFIG_PATH, INSTALL_CONFIG_PATH)
    shutil.rmtree(TEMP_CONFIG_PATH)
    print()

    info("Installing NixOS ...")
    run([*NIXOS_INSTALL, "--flake", f"path:{INSTALL_CONFIG_PATH}#{host}"], silent=True, dry=dry_run)
    print()

    info("Setup user passwords to complete installation")
    if not dry_run:
        INSTALL_PASSWORDS_PATH.mkdir(parents=True)
    passwd = (Path("/") if dry_run else INSTALL_PATH) / "etc" / "passwd"
    for user, *_, login_shell in map(lambda line: line.split(":"), passwd.read_text().splitlines()):
        if login_shell.endswith("bin/nologin"):
            continue

        while True:
            password = getpass(f"password for {user}: ")
            retyped = getpass(f"retype password for {user}: ")
            if password == retyped:
                break
            error("passwords do not match", prefix="", end="\n\n")

        if not dry_run:
            hashed_password = run(["mkpasswd", password], stdout=True).stdout.strip()
            (INSTALL_PASSWORDS_PATH / user).write_bytes(hashed_password)
        print()

    success("Successfully installed NixOS!", prefix="")
    hint("reboot now to finish installation")


DISKO_DEVICES_REGEX = re.compile(r"device\s+=\s+\(devices\)\.(\w+)")

SELECT_KWARGS: dict[str, Any] = dict(deselected_prefix="  ", selected_prefix="> ")
SILENT: dict[str, Any] = dict(stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

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
]

NIXOS_INSTALL = ["nixos-install", "--no-root-passwd", "--root", str(INSTALL_PATH)]


def run(
    command: str | list[str],
    cwd=TEMP_CONFIG_PATH,
    check=True,
    silent=False,
    stdout=False,
    dry=False,
) -> subprocess.CompletedProcess[Any]:
    if isinstance(command, str):
        command = command.split()

    if dry:
        assert not stdout
        command = " ".join(command)
        info(f"[dry] would run '{command}' in '{cwd}'")
        return cast(subprocess.CompletedProcess, object())

    return subprocess.run(
        command,
        cwd=cwd,
        check=check,
        capture_output=stdout,
        **(SILENT if silent and not stdout else {}),
    )


def main():
    parser = ArgumentParser()
    parser.add_argument("config_url", metavar="nixos-config-url")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    install(**args.__dict__)


if __name__ == "__main__":
    main()
