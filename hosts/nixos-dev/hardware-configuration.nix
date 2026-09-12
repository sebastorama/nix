# Shared x86_64 QEMU VM layout: ext4 root labeled nixos, no swap.
# See README.md for fresh-install setup and UEFI adjustments.
{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot = {
    initrd.availableKernelModules = [
      "ata_piix"
      "uhci_hcd"
      "virtio_pci"
      "virtio_blk"
      "virtio_scsi"
      "ahci"
      "nvme"
      "sd_mod"
      "sr_mod"
    ];
    initrd.kernelModules = [ ];
    extraModulePackages = [ ];

    # Legacy BIOS boot. Set this to the VM's whole disk (e.g. /dev/vda).
    loader.grub = {
      enable = true;
      device = lib.mkDefault "/dev/sda";
    };
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
}
