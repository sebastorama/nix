{ inputs, hostname, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  boot = {
    loader.grub = {
      enable = true;
      device = "/dev/sda";
      useOSProber = true;
    };
    kernelModules = [ "virtio_gpu" ];
  };

  networking = {
    hostName = hostname;
    networkmanager.enable = true;
  };

  time.timeZone = "America/Porto_Velho";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "pt_BR.UTF-8";
      LC_IDENTIFICATION = "pt_BR.UTF-8";
      LC_MEASUREMENT = "pt_BR.UTF-8";
      LC_MONETARY = "pt_BR.UTF-8";
      LC_NAME = "pt_BR.UTF-8";
      LC_NUMERIC = "pt_BR.UTF-8";
      LC_PAPER = "pt_BR.UTF-8";
      LC_TELEPHONE = "pt_BR.UTF-8";
      LC_TIME = "pt_BR.UTF-8";
    };
  };

  console.keyMap = "dvorak";

  hardware.graphics.enable = true;
  services = {
    xserver = {
      enable = true;
      videoDrivers = [ "modesetting" ];
      xkb = {
        layout = "us";
        variant = "alt-intl";
      };
      displayManager.lightdm.enable = true;
      desktopManager.xfce = {
        enable = true;
        enableScreensaver = false;
      };
    };

    qemuGuest.enable = true;
    xrdp = {
      enable = true;
      openFirewall = true;
      defaultWindowManager = "xfce4-session";
      # nixpkgs builds xorgxrdp without glamor, and its DRI3 support only
      # exists behind that flag. Rebuild it with glamor and allow the VirGL
      # driver (virtio_gpu) so X clients like Chrome render on the host iGPU.
      extraConfDirCommands =
        let
          stock = pkgs.xrdp.xorgxrdp;
          xorgxrdp = stock.overrideAttrs (old: {
            buildInputs = old.buildInputs ++ [
              pkgs.libepoxy
              pkgs.libgbm
            ];
            configureFlags = (old.configureFlags or [ ]) ++ [ "--enable-glamor" ];
            postInstall = (old.postInstall or "") + ''
              sed -i 's/"amdgpu i915 msm radeon"/"amdgpu i915 msm radeon virtio_gpu"/' \
                $out/etc/X11/xrdp/xorg.conf
              grep -q virtio_gpu $out/etc/X11/xrdp/xorg.conf
            '';
          });
        in
        ''
          substituteInPlace $out/sesman.ini --replace-fail ${stock} ${xorgxrdp}
        '';
    };
    printing.enable = true;
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };

    tailscale.enable = true;
  };

  security.rtkit.enable = true;

  virtualisation = {
    containers.enable = true;
    podman = {
      enable = true;
      dockerCompat = true;
      dockerSocket.enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  users.users.sebastorama = {
    isNormalUser = true;
    description = "Sebastião Giacheto Ferreira Júnior";
    extraGroups = [
      "networkmanager"
      "podman"
      "wheel"
    ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBKRZxH/8/sjYwFTS9+uyWOdMwib/Kv3KPFaI8pcTHN5 codex-nixos-installer"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIH8DdVdEsmE9hGP/6yC+sZ4Ix0an396qftBkcJp3z5c"
    ];
  };

  programs = {
    firefox.enable = true;
    nix-ld.enable = true;
    zsh.enable = true;
  };

  environment.systemPackages = with pkgs; [
    curl
    docker-compose
    ghostty.terminfo
    git
    htop
    rsync
    vim
    wget
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs hostname;
      system = pkgs.system;
    };
    users.sebastorama = import ../../home.nix;
  };

  system.stateVersion = "26.05";
}
