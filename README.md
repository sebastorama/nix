# sebastorama nix-darwin configuration

1. Add Full Disk Access to 'Terminal.app'
2. Install [Homebrew](https://brew.sh/)
3. Install [Nix-Determinate Systems](https://github.com/DeterminateSystems/nix-installer)
4. Login in the Mac App Store
5. Clone this repo to `~/nix` with `git clone --recurse-submodules <repo-url> ~/nix`
6. Run `nix run nix-darwin -- switch --flake ~/nix#14m3`
7. Make some coffee (it'll take a while)
8. Profit

For existing clones, initialize submodules with `git submodule update --init --recursive`.
Private submodules require authenticated GitHub SSH access.

`~/.claude` resolves to `dotfiles/claude`; runtime state and secrets remain ignored by the child repository.

To update the Claude config, commit and push the child repository's `main` branch, then update and commit the parent repository's gitlink.

## NixOS VMs

The `nixos-dev` and `nixos-sapb1` flake targets share
`hosts/nixos-dev/configuration.nix` and its hardware module. They use an ext4
root filesystem labeled `nixos`, with `/home`, `/nix`, and `/boot` on that same
filesystem, and no configured swap. Filesystem UUIDs can differ between VMs.

The default boot setup is **legacy BIOS on `/dev/sda`**, for x86_64 QEMU VMs.
During a fresh NixOS installation, choose ext4, no swap, and no separate `/home`
or `/boot`. With GPT and BIOS boot, retain the small unformatted BIOS boot
partition required by GRUB; the rest can be the ext4 root partition.

### Proxmox: nixos-dev

Use `#nixos-dev` for the new Proxmox dev VM (named `nixos-dev01` in Proxmox).
The guest hostname will be `nixos-dev`. This target includes the
shared QEMU guest agent service and enables weekly TRIM. In Proxmox, enable
QEMU Agent, Discard, and SSD emulation; use VirtIO SCSI single with an I/O
thread. RAM (16 GiB) and vCPUs (8, CPU type `host`) are configured in Proxmox.

For a fresh install, after preparing the BIOS/ext4 layout described above
and mounting its root at `/mnt`, run from the installer with this updated
repository available at `~/nix`:

```sh
sudo nixos-install --flake ~/nix#nixos-dev
```

For an existing installation, follow the layout checks below and use:

```sh
sudo nixos-rebuild switch --flake ~/nix#nixos-dev
```

Keep repositories, worktrees, and the pnpm store on the same local filesystem
so pnpm can hard-link packages. After boot, verify the services with
`systemctl status qemu-guest-agent` and `systemctl list-timers fstrim.timer`.

### Apply to an installed NixOS VM

1. Clone this repository to `~/nix` as described above.
2. Check the installed layout and boot mode:

   ```sh
   findmnt -no SOURCE,FSTYPE /
   lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MOUNTPOINTS
   test -d /sys/firmware/efi && echo UEFI || echo BIOS
   ```

3. If root is ext4, label its existing filesystem `nixos`. For example, if the
   root source shown above is `/dev/sda1`:

   ```sh
   sudo e2label /dev/sda1 nixos
   sudo udevadm settle
   ls -l /dev/disk/by-label/nixos
   ```

   Substitute the actual root partition. This changes its label without
   formatting it. Only one attached filesystem should carry this label. If
   the installation uses Btrfs, LUKS, LVM, or separate filesystems, adapt the
   hardware module to that layout before rebuilding; this config does not
   convert or repartition disks.

4. In `hosts/nixos-dev/hardware-configuration.nix`, set
   `boot.loader.grub.device` to the actual **whole disk**, such as `/dev/vda`
   for a VirtIO block disk. Keep `/dev/sda` if it matches the VM. For UEFI,
   use the adjustment below instead. The flake imports the hardware file in
   this repository, not `/etc/nixos/hardware-configuration.nix`.
5. Apply the chosen target:

   ```sh
   sudo nixos-rebuild switch --flake ~/nix#nixos-dev
   ```

   Use `#nixos-sapb1` for that hostname. After a successful rebuild, reboot.
   Removing the swap configuration does not delete or reclaim an existing
   swap partition; choose no swap during installation to give that space to root.

### UEFI installations

UEFI requires a FAT EFI System Partition in addition to the ext4 root. Keep
the fresh install's EFI partition, label it `boot` (for example with
`sudo fatlabel /dev/sda1 boot`, using the actual EFI partition), and replace
the hardware module's `loader.grub` block with:

```nix
loader.systemd-boot.enable = true;
loader.efi.canTouchEfiVariables = true;
```

Add this beside `fileSystems."/"` at the module's top level:

```nix
fileSystems."/boot" = {
  device = "/dev/disk/by-label/boot";
  fsType = "vfat";
  options = [ "fmask=0077" "dmask=0077" ];
};
```

### Disko

[Disko](https://github.com/nix-community/disko) is an option for automating
partitioning and formatting before installation. It is unnecessary for adopting
this configuration on an already installed ext4 VM. The rebuild command above
only configures mounts and the system; it does not format disks.

See the [NixOS installation manual](https://nixos.org/manual/nixos/stable/#sec-installation-manual)
for the BIOS and UEFI installation layouts.

## Commands
