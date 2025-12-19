# NixOS Configuration with Flakes and Disko

This repository now includes a full NixOS configuration with flakes and disko for disk formatting.

## Prerequisites

- A machine or VM where you want to install NixOS
- Access to a live NixOS installer
- Your disk device name (e.g., `/dev/sda`, `/dev/nvme0n1`)

## Configuration Overview

### Files Structure

- `flake.nix` - Main flake configuration with inputs and outputs
- `configuration.nix` - NixOS system configuration
- `disko.nix` - Disk partitioning and formatting configuration
- `home.nix` - Home Manager configuration (your dotfiles and packages)

### Current Disko Setup

The current `disko.nix` is configured with:
- **UEFI boot partition**: 512MB on `/boot`
- **LUKS encryption**: Full disk encryption
- **LVM setup**:
  - 8GB swap partition
  - Root partition using remaining space

**IMPORTANT**: Before using, update these settings in `disko.nix`:
1. Change the disk device from `/dev/sda` to your actual disk (e.g., `/dev/nvme0n1`)
2. Update the password file path from `/tmp/secret.key` to your preferred location
3. Adjust swap size if needed (currently 8GB)

## Installation Steps

### 1. Boot into NixOS Installer

Boot your machine from a NixOS installation media.

### 2. Update Disko Configuration

Clone this repository and edit `disko.nix`:

```bash
# Identify your disk
lsblk

# Edit disko.nix and update:
# - device = "/dev/sda" to your actual disk
# - passwordFile path
# - swap size if needed
```

### 3. Create LUKS Password File

```bash
# Create a temporary password file for LUKS encryption
echo "your-secure-password" > /tmp/secret.key
chmod 600 /tmp/secret.key
```

### 4. Partition and Format Disk with Disko

```bash
# Navigate to your nix directory
cd /path/to/nix

# Run disko to partition and format the disk
# WARNING: This will ERASE all data on the disk!
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode disko \
  ./disko.nix
```

### 5. Generate Hardware Configuration

```bash
# Generate hardware-config.nix
nixos-generate-config --no-filesystems --root /mnt

# Copy the hardware configuration to your repo
cp /mnt/etc/nixos/hardware-configuration.nix ./hardware-configuration.nix
```

### 6. Update Configuration.nix

Add the hardware configuration import to `configuration.nix`:

```nix
imports = [
  ./disko.nix
  ./hardware-configuration.nix  # Add this line
  inputs.home-manager.nixosModules.home-manager
];
```

### 7. Install NixOS

```bash
# Install NixOS using your flake
sudo nixos-install --flake .#nixos

# Set root password when prompted
# The user password will be disabled (SSH key auth only)
```

### 8. Reboot

```bash
sudo reboot
```

## Post-Installation

### First Login

After reboot, you can login with your user `sebastorama`. Since password authentication is disabled, you'll need to:

1. Either add your SSH public key to the `openssh.authorizedKeys.keys` list in `configuration.nix`
2. Or temporarily enable password auth for initial setup

### Rebuild System

After making changes to the configuration:

```bash
# From your nix directory
sudo nixos-rebuild switch --flake .#nixos
```

### Update Flake Inputs

```bash
# Update all inputs
nix flake update

# Rebuild with updated inputs
sudo nixos-rebuild switch --flake .#nixos
```

## Customization

### Change Hostname

Edit `flake.nix` and update:

```nix
nixosConfigurations = {
  "your-hostname" = mkNixosSystem "your-hostname" "x86_64-linux";
};
```

Then rebuild with `sudo nixos-rebuild switch --flake .#your-hostname`

### Adjust Disk Layout

Edit `disko.nix` to customize:
- Partition sizes
- Add/remove partitions
- Change filesystem types
- Add separate `/home` partition

### Enable Graphical Environment

Uncomment in `configuration.nix`:

```nix
services.xserver.enable = true;
services.xserver.displayManager.gdm.enable = true;
services.xserver.desktopManager.gnome.enable = true;
```

Or choose another desktop environment like KDE, XFCE, etc.

### Disable LUKS Encryption

If you don't want encryption, modify `disko.nix` to remove the LUKS layer and use direct partitions.

## Building Without Installing

To test your configuration without installing:

```bash
# Build the system configuration
nix build .#nixosConfigurations.nixos.config.system.build.toplevel

# Check for errors
nix flake check
```

## Troubleshooting

### Disk Device Not Found

Make sure the device in `disko.nix` matches your actual disk:
```bash
lsblk -d -o NAME,SIZE,TYPE
```

### LUKS Password Issues

Ensure the password file exists and is readable:
```bash
ls -la /tmp/secret.key
cat /tmp/secret.key  # Should show your password
```

### Boot Issues

If the system doesn't boot:
1. Boot back into the installer
2. Decrypt and mount your partitions
3. Check `/mnt/boot` has the bootloader files
4. Verify `/mnt/etc/nixos/hardware-configuration.nix` is correct

### Module Errors

If you get module-related errors during `nix flake check`:
1. Ensure all files are tracked by git: `git add .`
2. Run `nix flake check` again

## Alternative Disk Layouts

### Simple Unencrypted Layout

For a simpler setup without encryption, you can replace the disko configuration with:

```nix
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
```

## Additional Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Disko Documentation](https://github.com/nix-community/disko)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
