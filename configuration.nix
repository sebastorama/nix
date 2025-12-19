{ config, lib, pkgs, inputs, hostname, ... }:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  # WSL Configuration
  wsl = {
    enable = true;
    defaultUser = "sebastorama";
    startMenuLaunchers = true;
  };

  # Boot loader configuration for UEFI (disabled for WSL)
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;

  # Kernel parameters (disabled for WSL - uses Windows kernel)
  # boot.kernelPackages = pkgs.linuxPackages_latest;

  # Networking
  networking.hostName = hostname;
  # networking.networkmanager.enable = true;  # Disabled for WSL

  # Time zone and locale
  time.timeZone = "America/Sao_Paulo";  # Change to your timezone
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # User configuration
  users.users.sebastorama = {
    isNormalUser = true;
    description = "Sebastião Giacheto Ferreira Júnior";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      # Add your SSH public keys here
    ];
  };

  # Enable sudo without password for wheel group
  security.sudo.wheelNeedsPassword = false;

  # Home Manager integration
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs hostname; system = pkgs.system; };
    users.sebastorama = import ./home.nix;
  };

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
    htop
  ];

  # Enable essential services
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Enable Docker
  virtualisation.docker.enable = true;

  # Enable zsh system-wide
  programs.zsh.enable = true;

  programs.nix-ld.enable = true;

  # Enable sound with pipewire (disabled for WSL)
  # services.pulseaudio.enable = false;
  # security.rtkit.enable = true;
  # services.pipewire = {
  #   enable = true;
  #   alsa.enable = true;
  #   alsa.support32Bit = true;
  #   pulse.enable = true;
  # };

  # Graphics and display server (if needed)
  # Uncomment if you want a graphical environment
  # services.xserver.enable = true;
  # services.xserver.displayManager.gdm.enable = true;
  # services.xserver.desktopManager.gnome.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "24.05";
}
