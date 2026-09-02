{ inputs, hostname, lib, pkgs, ... }:

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
    sunshine = {
      enable = true;
      openFirewall = true;
      # virtio-gpu has no KMS cursor plane, so KMS capture would stream an
      # invisible pointer; X11 capture composites the cursor via XFixes.
      settings.capture = "x11";
      # virtio-gpu accepts arbitrary modes, so resize the virtual display to
      # whatever Moonlight asks for instead of upscaling 1280x800.
      applications.apps = [
        {
          name = "Desktop";
          prep-cmd = [
            {
              do = pkgs.writeShellScript "sunshine-match-resolution" ''
                export PATH=${lib.makeBinPath [ pkgs.gnused pkgs.xrandr pkgs.xorgserver ]}
                mode="$SUNSHINE_CLIENT_WIDTH"x"$SUNSHINE_CLIENT_HEIGHT"
                xrandr --newmode "$mode" $(gtf "$SUNSHINE_CLIENT_WIDTH" "$SUNSHINE_CLIENT_HEIGHT" 60 \
                  | sed -n 's/^ *Modeline "[^"]*" *//p') 2>/dev/null || true
                xrandr --addmode Virtual-1 "$mode" 2>/dev/null || true
                xrandr --output Virtual-1 --mode "$mode" || true
              '';
            }
          ];
          auto-detach = "true";
        }
      ];
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

  systemd.user.services.sunshine = {
    # xrdp logins push DISPLAY=:10 into the systemd user environment; Sunshine
    # must always capture the seat0 session.
    environment.DISPLAY = ":0";
    # At boot the autologin session (and a reconnecting Moonlight) can beat
    # PipeWire; Sunshine then fails to set its default sink and the stream
    # runs without audio.
    after = [
      "pipewire-pulse.service"
      "wireplumber.service"
    ];
    wants = [
      "pipewire-pulse.service"
      "wireplumber.service"
    ];
  };

  security.rtkit.enable = true;
  security.sudo.wheelNeedsPassword = false;

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
