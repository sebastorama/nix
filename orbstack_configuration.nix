{
  config,
  lib,
  pkgs,
  inputs,
  hostname,
  modulesPath,
  ...
}:

let
  watchdogServices = [
    "systemd-homed"
    "systemd-hostnamed"
    "systemd-importd"
    "systemd-journald"
    "systemd-journald@"
    "systemd-journal-remote"
    "systemd-journal-upload"
    "systemd-localed"
    "systemd-logind"
    "systemd-machined"
    "systemd-nspawn@"
    "systemd-oomd"
    "systemd-portabled"
    "systemd-timedated"
    "systemd-timesyncd"
    "systemd-udevd"
    "systemd-userdbd"
  ];
in
{
  imports = [
    "${modulesPath}/virtualisation/lxc-container.nix"
    inputs.home-manager.nixosModules.home-manager
  ];

  networking = {
    hostName = hostname;
    dhcpcd.enable = false;
    firewall.allowedTCPPorts = [ 17318 ];
    resolvconf.enable = false;
    useDHCP = false;
    useHostResolvConf = false;
  };

  systemd = {
    network = {
      enable = true;
      networks."50-eth0" = {
        matchConfig.Name = "eth0";
        networkConfig = {
          DHCP = "ipv4";
          IPv6AcceptRA = true;
        };
        linkConfig.RequiredForOnline = "routable";
      };
    };
    services =
      lib.genAttrs watchdogServices (_: {
        serviceConfig.WatchdogSec = 0;
      })
      // {
        systemd-networkd.serviceConfig.WatchdogSec = lib.mkIf config.systemd.network.enable 0;
      };
    # OrbStack containers cannot mount debugfs themselves.
    units."sys-kernel-debug.mount".enable = false;
  };

  # Keep OrbStack's guest integration while avoiding access to macOS files.
  environment = {
    etc."resolv.conf".source = "/opt/orbstack-guest/etc/resolv.conf";
    shellInit = ''
      . /opt/orbstack-guest/etc/profile-early
      . /opt/orbstack-guest/etc/profile-late
    '';
    systemPackages = with pkgs; [
      curl
      git
      htop
      rsync
      vim
      wget
    ];
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };
    resolved.enable = false;
  };

  programs = {
    nix-ld.enable = true;
    ssh.extraConfig = ''
      Include /opt/orbstack-guest/etc/ssh_config
    '';
    zsh.enable = true;
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    extra-platforms = [
      "x86_64-linux"
      "i686-linux"
    ];
  };

  users = {
    mutableUsers = false;
    groups.orbstack.gid = 67278;
    users.sebastorama = {
      uid = 501;
      isSystemUser = true;
      group = "users";
      extraGroups = [
        "audio"
        "docker"
        "orbstack"
        "wheel"
      ];
      createHome = true;
      home = "/home/sebastorama";
      homeMode = "700";
      shell = pkgs.zsh;
      useDefaultShell = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIH8DdVdEsmE9hGP/6yC+sZ4Ix0an396qftBkcJp3z5c"
      ];
    };
  };

  security.sudo.wheelNeedsPassword = false;
  time.timeZone = "America/Sao_Paulo";

  virtualisation.docker.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs hostname;
      system = pkgs.system;
    };
    users.sebastorama = import ./home.nix;
  };

  # Match the version used when this OrbStack machine was created.
  system.stateVersion = "25.11";
}
