{ pkgs, self, system, hostname, ... }: {
  # allowUnfree and the platform are set on the pkgs instance built in
  # flake.nix (mkPkgs), which is injected via nixpkgs.pkgs.
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
      "docker-desktop"
      "doppler"
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
      "imagemagick"
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
      "orion"
      "parsec"
      "parallels"
      "qgis"
      "qmk-toolbox"
      "raycast"
      "slack"
      "steam"
      "steelseries-gg"
      "spotify"
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
      "wasabi-wallet"
      "whatsapp"
      "wifiman"
      "zed@preview"
      "zen"
    ];

    brews = [
      "cloudflared"
      "findutils"
      "gnupg"
      "graphviz"
      "haskell-stack"
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
    magnification = true;
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
    "com.apple.keyboard.fnState" = false;
    ApplePressAndHoldEnabled = false;
    AppleShowScrollBars = "Always";
    InitialKeyRepeat = 15;
    KeyRepeat = 2;
    NSWindowShouldDragOnGesture = true;
  };

  system.keyboard = {
    enableKeyMapping = false;
  };

  networking.hostName = hostname;

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
