# Generated from nixos01-dev's existing /etc/nixos/hardware-configuration.nix.
{ modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot = {
    initrd.availableKernelModules = [
      "ata_piix"
      "uhci_hcd"
      "virtio_pci"
      "virtio_scsi"
      "sd_mod"
      "sr_mod"
    ];
    initrd.kernelModules = [ ];
    extraModulePackages = [ ];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/6c5bf74b-954e-48f6-8eb0-8f1fef7546f4";
    fsType = "ext4";
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/af97b403-9381-42d0-a5df-9877d1170140"; }
  ];
}
