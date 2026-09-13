{ inputs, hostname, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  networking = {
    hostName = hostname;
    hosts."192.168.183.200" = [ "pve" ];
    networkmanager = {
      enable = true;
      ensureProfiles.profiles.ens18 = {
        connection = {
          id = "Wired connection 1";
          uuid = "526dfb3f-d590-3d78-93b4-9971a26f856f";
          type = "ethernet";
          interface-name = "ens18";
          autoconnect = true;
        };
        ipv4 = {
          method = "manual";
          address1 = "192.168.183.201/24,192.168.183.1";
          dns = "192.168.183.1;";
        };
        ipv6.method = "auto";
      };
    };
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
    # Return unused blocks to Proxmox's thin storage (disk Discard enabled).
    fstrim = {
      enable = hostname == "nixos-dev";
      interval = "weekly";
    };

    # Sunshine captures the seat0 desktop, so keep an XFCE session running
    # on the virtual display (:0) instead of parking at the greeter.
    displayManager = {
      defaultSession = "xfce";
      autoLogin = {
        enable = true;
        user = "sebastorama";
      };
    };

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
      # The autologin XFCE session on :0 already owns org.xfce.SessionManager
      # on the systemd user bus; give RDP logins their own bus so a second
      # xfce4-session can start.
      defaultWindowManager = "${pkgs.dbus}/bin/dbus-run-session xfce4-session";
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
  security.sudo.wheelNeedsPassword = false;

  virtualisation = {
    docker.enable = true;
    oci-containers = {
      backend = "docker";
      containers.portainer = {
        image = "portainer/portainer-ce:lts";
        ports = [ "9443:9443" ];
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
          "portainer_data:/data"
        ];
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 9443 ];

  users.users.sebastorama = {
    isNormalUser = true;
    description = "Sebastião Giacheto Ferreira Júnior";
    extraGroups = [
      "networkmanager"
      "docker"
      "uinput"
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
