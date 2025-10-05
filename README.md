#  Core modules for NixOS Configurations 

## Usage

### `flake.nix`

```nix
{
    inputs = {
        nixpkgs.url = ...;
        nixpkgs-unstable.url = ...;

        nixos-core = {
            url = "github:30350n/nixos-core";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
        };
    };

    outputs = {
        self,
        nixpkgs,
        nixpkgs-unstable,
        nixos-core,
        ...
    } @ flake-inputs: {
        nixosConfigurations = {
            system = nixpkgs.lib.nixosSystem {
                specialArgs = {
                    inherit flake-inputs;
                };
                modules = [
                    nixos-core.nixosModules.nixos-core
                    ...
                ];
            };
        };
    };
}
```

### Directory Structure

For configurations to be installable via the [`nixos-core#install`](install) command, the following directory structure must be used:

```shell
<config-root>/
├── hosts/<hostname>/
│   ├── disko.nix
│   ├── devices.nix                 # created by install script, should be imported by disko.nix
│   └── hardware-configuration.nix  # created by install script
│   └── host-id.nix                 # created by install script
```

## Installation

### Using [minimal ISO image](https://nixos.org/download/)

```shell
$ sudo nix --experimental-features "nix-command flakes" run github:30350n/nixos-core#install -- <config-url>
```

### Using [custom nixos-core#nixos-iso image](installer/nixos-iso.nix)

```shell
$ sudo install <config-url>
```

## Building [custom nixos-core#nixos-iso image](installer/nixos-iso.nix)

```
$ nix build github:30350n/nixos-core#nixos-iso
```
