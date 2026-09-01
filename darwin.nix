{ pkgs, self, system, hostname, ... }: {
  # allowUnfree and the platform are set on the pkgs instance built in
  # flake.nix (mkPkgs), which is injected via nixpkgs.pkgs.

  # nix-darwin (a1fa429) still passes --toc-depth to nixos-render-docs,
  # which newer nixpkgs removed; skip the HTML manual until upstream fixes it.
  # The uninstaller embeds a default-config system that also builds the
  # manual, so it has to go too.
  documentation.doc.enable = false;
  system.tools.darwin-uninstaller.enable = false;
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    cmake
    goku
    vim
  ];

  homebrew = {
    enable = true;

    taps = [
      "dopplerhq/cli"
      "jeffreywildman/virt-manager"
      "modem-dev/tap"
      "qmk/qmk"
      "typewhisper/tap"
      "xykong/tap"
    ];

    casks = [
      "1password"
      "1password-cli"
      "adobe-acrobat-pro"
      "alfred"
      "android-platform-tools"
      "android-studio"
      "arc"
      "arduino-ide"
      "balenaetcher"
      "bambu-studio"
      "brave-browser"
      "claude"
      "cmux"
      "cursor"
      "devpod"
      "discord"
      "dockdoor"
      "dropbox"
      "firefox"
      "flux-markdown"
      "focusrite-control"
      "ghostty"
      "google-chrome"
      "google-chrome@canary"
      "google-earth-pro"
      "handbrake-app"
      "heynote"
      "hyperkey"
      "iina"
      "iterm2"
      "jetbrains-toolbox"
      "karabiner-elements"
      "keymapp"
      "kicad"
      "kitty"
      "logi-options+"
      "logitech-g-hub"
      "mattermost"
      "microsoft-edge"
      "microsoft-office"
      "ngrok"
      "nordvpn"
      "notion"
      "obs"
      "obs-backgroundremoval"
      "obsidian"
      "ollama-app"
      "orbstack"
      "orion"
      "parsec"
      "parallels"
      "qbittorrent"
      "qmk-toolbox"
      "raycast"
      "slack"
      "spotify"
      "stats"
      "steam"
      "steelseries-gg"
      "supacode"
      "teamviewer"
      "telegram"
      "textual"
      "the-unarchiver"
      "todoist-app"
      "transcribe"
      "typewhisper"
      "visual-studio-code"
      "vial"
      "vnc-viewer"
      "vivaldi"
      "wifiman"
      "zed@preview"
      "zen"
    ];

    brews = [
      "cliproxyapi"
      "cloudflared"
      "findutils"
      "gnupg"
      "graphviz"
      "haskell-stack"
      "jeffreywildman/virt-manager/virt-viewer"
      "modem-dev/tap/hunk"
      "openjdk"
      "sevenzip"
      "terminal-notifier"
    ];

    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
  };

  nix.enable = false; # managed by determinate
  # nix.package = pkgs.nix;

  nix.settings.experimental-features = "nix-command flakes";

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true;  # default shell on catalina

  system.primaryUser = "sebastorama";

  # Set Git commit hash for darwin-version.
  system.configurationRevision = self.rev or self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  fonts.packages = with pkgs; [
    nerd-fonts.iosevka
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
  ];

  system.defaults.dock = {
    autohide = true;
    tilesize = 44;
    largesize = 96;
    magnification = false;
    showhidden = true;
    scroll-to-open = true;
    orientation = "bottom";
    show-recents = false;
    appswitcher-all-displays = true;
  };

  system.defaults.finder = {
    AppleShowAllExtensions = true;
    ShowStatusBar = true;
    ShowPathbar = true;
    FXPreferredViewStyle = "Nlsv";
    FXDefaultSearchScope = "SCcf";
  };

  system.defaults.trackpad = {
    TrackpadThreeFingerDrag = true;
    Dragging = false;
    Clicking = true;
  };

  system.defaults.NSGlobalDomain = {
    "com.apple.keyboard.fnState" = true;
    ApplePressAndHoldEnabled = false;
    AppleShowScrollBars = "Always";
    InitialKeyRepeat = 15;
    KeyRepeat = 2;
    NSWindowShouldDragOnGesture = true;
  };

  # Hyper+A (⌃⌥⇧⌘A via Hyperkey) -> "Move focus to the Dock" (symbolic hotkey 8)
  # Hyper+1 (⌃⌥⇧⌘1 via Hyperkey) -> "Mission Control" (symbolic hotkey 32)
  # Hyper+2 (⌃⌥⇧⌘2 via Hyperkey) -> "Application Windows" (symbolic hotkey 33)
  # Hyper+3 (⌃⌥⇧⌘3 via Hyperkey) -> "Show Desktop" (symbolic hotkey 36)
  system.defaults.CustomUserPreferences."com.apple.symbolichotkeys" = {
    # Spotlight search: Option+Command+Space
    AppleSymbolicHotKeys."64" = {
      enabled = true;
      value = {
        parameters = [ 32 49 1572864 ];
        type = "standard";
      };
    };
    # Finder search: Control+Command+Space
    AppleSymbolicHotKeys."65" = {
      enabled = true;
      value = {
        parameters = [ 32 49 1310720 ];
        type = "standard";
      };
    };
    # Show Apps
    AppleSymbolicHotKeys."160".enabled = false;

    AppleSymbolicHotKeys."8" = {
      enabled = true;
      value = {
        parameters = [
          97       # ASCII "a"
          0        # keycode for A
          1966080  # shift+ctrl+opt+cmd
        ];
        type = "standard";
      };
    };
    AppleSymbolicHotKeys."32" = {
      enabled = true;
      value = {
        parameters = [
          49       # ASCII "1"
          18       # keycode for 1
          1966080  # shift+ctrl+opt+cmd
        ];
        type = "standard";
      };
    };
    AppleSymbolicHotKeys."33" = {
      enabled = true;
      value = {
        parameters = [
          50       # ASCII "2"
          19       # keycode for 2
          1966080  # shift+ctrl+opt+cmd
        ];
        type = "standard";
      };
    };
    AppleSymbolicHotKeys."36" = {
      enabled = true;
      value = {
        parameters = [
          51       # ASCII "3"
          20       # keycode for 3
          1966080  # shift+ctrl+opt+cmd
        ];
        type = "standard";
      };
    };
  };

  system.keyboard = {
    enableKeyMapping = false;
  };

  networking.hostName = hostname;

  services.openssh = {
    enable = true;
    extraConfig = ''
      PermitRootLogin no
      PasswordAuthentication no
      KbdInteractiveAuthentication no
    '';
  };

  security.sudo.extraConfig = ''
    sebastorama ALL=(ALL) NOPASSWD: ALL
  '';
  security.pam.services.sudo_local.touchIdAuth = true;
  environment = {
    etc."pam.d/sudo_local".text = ''
      # Managed by Nix Darwin
      auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so ignore_ssh
      auth       sufficient     pam_tid.so
    '';
  };
}
