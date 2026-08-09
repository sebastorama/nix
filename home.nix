{ config, lib, pkgs, _system, inputs, hostname, ... }:

let
  # Detect home directory based on system
  homeDir = if pkgs.stdenv.isDarwin then "/Users/sebastorama" else "/home/sebastorama";
  dotfilesPath = "${homeDir}/nix/dotfiles";
  nodejsPackage = pkgs.nodejs_26;
  npmGlobalPrefix = "${homeDir}/.npm-packages";
  npmGlobalEnv = ''
    export NPM_CONFIG_PREFIX="${npmGlobalPrefix}"
    run mkdir -p "$NPM_CONFIG_PREFIX"
  '';
  herdrPackage = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
  herdrRecentNavigator = pkgs.rustPlatform.buildRustPackage rec {
    pname = "herdr-recent-navigator";
    src = inputs.herdr-recent-navigator;
    version = (builtins.fromTOML (builtins.readFile "${src}/Cargo.toml")).package.version;

    cargoLock.lockFile = "${src}/Cargo.lock";

    postInstall = ''
      cp herdr-plugin.toml "$out/herdr-plugin.toml"
      substituteInPlace "$out/herdr-plugin.toml" \
        --replace-fail './target/release/herdr-recent-navigator' './bin/herdr-recent-navigator'
    '';
  };
  herdrNavigator = pkgs.rustPlatform.buildRustPackage rec {
    pname = "herdr-navigator";
    src = inputs.herdr-navigator;
    version = (builtins.fromTOML (builtins.readFile "${src}/Cargo.toml")).package.version;

    cargoLock.lockFile = "${src}/Cargo.lock";

    postInstall = ''
      cp herdr-plugin.toml "$out/herdr-plugin.toml"
      substituteInPlace "$out/herdr-plugin.toml" \
        --replace-fail 'bin/herdr-navigator' './bin/herdr-navigator' \
        --replace-fail 'alt+h' 'ctrl+h' \
        --replace-fail 'alt+j' 'ctrl+j' \
        --replace-fail 'alt+k' 'ctrl+k' \
        --replace-fail 'alt+l' 'ctrl+l'
    '';
  };
  herdrBar = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "herdr-bar";
    src = inputs.herdr-bar;
    version = (builtins.fromTOML (builtins.readFile "${src}/herdr-plugin.toml")).version;

    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -R . "$out"
      substituteInPlace "$out/herdr-plugin.toml" \
        --replace-fail 'command = ["python3", "run.py"]' 'command = ["${pkgs.python3}/bin/python3", "run.py"]'
      runHook postInstall
    '';
  };
in
{
  imports = [
    ./ssh.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "sebastorama";
  home.homeDirectory = homeDir;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "26.05"; # Please read the comment before changing.
  home.enableNixpkgsReleaseCheck = false;

  # The home.packages option allows you to install Nix packages into your
  # environment.

  home.packages = with pkgs; [
    act
    bc
    btop
    bun
    cargo
    claude-code
    copilot-language-server
    devcontainer
    doppler
    dotenv-cli
    eslint_d
    fd
    freerdp
    fzf
    gawk
    gcc
    gh
    gnumake
    herdrPackage
  ] ++ pkgs.lib.optionals (
    pkgs.stdenv.isLinux && pkgs.stdenv.hostPlatform.isx86_64
  ) [
    google-chrome
  ] ++ [
    gum
    imagemagick
    jq
    lazygit
    libxml2
    lsd
    mtr
    nil
    nixd
    nixfmt
    nodejsPackage
    pgformatter
    pipx
    (pnpm.override { nodejs-slim = nodejsPackage; })
    postgresql_18
    python3
    ripgrep
    (ruby_3_3.withPackages (rp: with rp; [
      bundler
      pry
    ]))
    sd
    sesh
    sqlite
    stdenv
    stylua
    tldr
    tmux
    tree-sitter
    typescript-language-server
    uv
    vscode-langservers-extracted
    wget
    xmlstarlet
    yt-dlp

    # Custom scripts
    (pkgs.writeShellScriptBin "only_numbers" ''
      sed 's/[^0-9]//g'
    '')

    # Nerd Fonts
    nerd-fonts.fantasque-sans-mono
    nerd-fonts.symbols-only

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    ".config/kitty/kitty.conf".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/kitty.conf";

    ".config/ghostty/config".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/ghostty_conf";

    ".config/hunk/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/hunk_config.toml";

    ".config/herdr/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/herdr_config.toml";

    ".config/nvim/".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/nvim";

    ".claude".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/claude";

    ".npmrc".source = dotfiles/npmrc;

    ".pi/agent/AGENTS.md".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/pi/AGENTS.md";

    ".config/opencode/AGENTS.md".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/pi/AGENTS.md";

    ".config/crush/crush.json".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/crush.json";

    ".config/claude/gpt-proxy.json".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/gpt-proxy.json";

    ".gitignore_global".text = ''
      .claude*
      .vscode
      .serena
    '';

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.local/scripts"
    "$HOME/.local/hm-bins/duo"
    "${npmGlobalPrefix}/bin"
  ];

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/sebastorama/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    EDITOR = "nvim";
    LC_CTYPE = "en_US.UTF-8";
    LC_ALL="en_US.UTF-8";
    LANG="en_US.UTF-8";
  } // lib.optionalAttrs (hostname == "nixos-orbstack") {
    PI_CHROME_BRIDGE_HOST = "0.0.0.0";
  };

  # Installed via npm rather than nixpkgs since it's not packaged there yet.
  # Lands in ~/.npm-packages (see dotfiles/npmrc), which is already on PATH
  # via home.sessionPath below.
  home.activation.linkHerdrRecentNavigator = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${herdrPackage}/bin/herdr plugin link ${herdrRecentNavigator} --enabled
  '';

  home.activation.linkHerdrNavigator = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${herdrPackage}/bin/herdr plugin link ${herdrNavigator} --enabled
  '';

  home.activation.linkHerdrBar = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${herdrPackage}/bin/herdr plugin link ${herdrBar} --enabled
  '';

  home.activation.installPiCodingAgent = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${npmGlobalEnv}
    run ${nodejsPackage}/bin/npm install -g --ignore-scripts @earendil-works/pi-coding-agent
  '';

  home.activation.installOpenCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${npmGlobalEnv}
    export PATH="${nodejsPackage}/bin:$PATH"
    run ${nodejsPackage}/bin/npm install -g opencode-ai
  '';

  home.activation.installPiPackages = lib.hm.dag.entryAfter [ "installPiCodingAgent" ] ''
    ${npmGlobalEnv}
    export PATH="${nodejsPackage}/bin:$PATH"
    run "${npmGlobalPrefix}/bin/pi" install npm:pi-web-access
    run "${npmGlobalPrefix}/bin/pi" install npm:pi-chrome
    run "${npmGlobalPrefix}/bin/pi" install npm:pi-ask-user
  '';

  programs.neovim.enable = true;
  programs.neovim.sideloadInitLua = true;

  programs.git = {
   enable = true;
   settings = {
     user.email = "sebastorama@gmail.com";
     user.name = "Sebastião Giacheto Ferreira Júnior";

     init.defaultBranch = "main";
     core.editor = "nvim";
     core.excludesfile = "~/.gitignore_global";
     merge.tool = "nvimdiff";
     mergetool."nvimdiff".cmd = "nvim -d \"$LOCAL\" \"$MERGED\" \"$BASE\" \"$REMOTE\" -c \"wincmd w\" -c \"wincmd J\"";
     diff.tool = "nvimdiff";
     difftool."nvimdiff".cmd = "nvim -d \"$LOCAL\" \"$REMOTE\"";

     alias = {
       st = "status -s";
       ci = "commit";
       co = "checkout";
       dc = "diff --cached";
       df = "diff";
       lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%ae>%Creset' --abbrev-commit";
     };
   };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      syntax-theme = "Nord";  # Dark theme similar to Tokyo Night
      line-numbers = true;
      side-by-side = false;
      navigate = true;
      hyperlinks = true;
      file-style = "bold yellow ul";
      file-decoration-style = "none";
      hunk-header-style = "file line-number syntax";
    };
  };


  programs.tmux = {
    enable = true;
    baseIndex = 1;
    disableConfirmationPrompt = true;
    mouse = true;
    newSession = false;
    aggressiveResize = true;
    keyMode = "vi";
    plugins = with pkgs.tmuxPlugins; [
      {
        # These options must be set BEFORE the theme's run-shell executes,
        # otherwise the status line is drawn with defaults and the settings
        # only take effect after a manual `source-file`. Home Manager emits a
        # plugin's extraConfig immediately before its run-shell, so keep all
        # @tokyo-night-tmux_* options here rather than in the block below.
        plugin = tokyo-night-tmux;
        extraConfig = ''
          set -g @tokyo-night-tmux_theme storm
          set -g @tokyo-night-tmux_window_tidy_icons 0

          # Use plain ASCII window numbers; the default "digital" style uses
          # Unicode Segmented Digits (U+1FBF0-9) that no Nerd Font ships, so
          # they render as tofu boxes.
          set -g @tokyo-night-tmux_window_id_style none
        '';
      }
      vim-tmux-navigator
      {
        # Save/restore full sessions: window (tab) names, pane layout & sizes,
        # working directories, and pane contents. resurrect MUST be listed
        # before continuum, which builds on it.
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-strategy-nvim 'session'
        '';
      }
      {
        # Automatically save every 15 min and auto-restore on tmux server start.
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
        '';
      }
      {
        # Fuzzy-find (via fzf popup) sessions, windows, panes, commands and
        # key bindings. Trigger with `prefix + F`.
        plugin = tmux-fzf;
        extraConfig = ''
          TMUX_FZF_LAUNCH_KEY="F"
        '';
      }
    ];
    extraConfig = ''
      set-window-option -g window-status-current-style fg=red
      set-option -g status-position top

      # tmux 3.7 draws the command prompt on top of the status line and only
      # clears the full width when message-style has a fill colour; the theme
      # predates this, so append one (storm background) to blank the bar.
      set -ga message-style "fill=#24283b"
      set -ga message-command-style "fill=#24283b"

      set -g default-terminal 'tmux-256color'

      set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'  # undercurl support
      set -as terminal-overrides ',*:Setulc=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'  # underscore colours - needs tmux-3.0

      # Use v to trigger selection
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      # Use y to yank current selection
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel

      bind c new-window -c "#{pane_current_path}"
      bind '"' split-window -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind-key C-u run-shell -b "tmux capture-pane -J -p | grep -oE '(https?):\/\/[^ ]*' | fzf-tmux -d20 --multi --bind alt-a:select-all,alt-d:deselect-all | xargs open"

      bind -r l select-pane -R
      bind -r h select-pane -L
      # Reorder windows; -d keeps focus on the moved window.
      bind -r "<" swap-window -d -t -1
      bind -r ">" swap-window -d -t +1
      bind -r z resize-pane -Z
      bind-key -n C-M-5 split-window -h

      bind-key "t" display-popup -E -w 40% "sesh connect \"$(
       sesh list -i | gum filter --limit 1 --no-sort --fuzzy --placeholder 'Pick a sesh' --height 50 --prompt='⚡'
      )\""

      bind-key -n C-M-PageUp swap-window -t -1\; select-window -t -1
      bind-key -n C-M-PageDown swap-window -t +1\; select-window -t +1

      bind-key C-Space select-pane -t .+\; resize-pane -Z

      bind-key -r 9 resize-pane -L 10
      bind-key -r 0 resize-pane -R 10
      bind-key -n F3 choose-tree -Zw
      bind-key F4 resize-pane -R 50


      bind-key -n S-F1 swap-window -t -1\; select-window -t -1
      bind-key -n S-F2 swap-window -t +1\; select-window -t +1

      bind-key -n M--  previous-window
      bind-key -n M-= next-window
      bind-key -n F4 resize-pane -Z
      bind-key ! break-pane -d -n _hidden_pane
      bind-key @ join-pane -s $.1

      bind-key -r C-l send-keys 'C-l'
      bind-key -r C-k send-keys 'C-k'

      # Right-click context menu with a Paste entry
      bind-key -n MouseDown3Pane display-menu -t = -x M -y M \
        "Paste"          p "paste-buffer -p" \
        "" \
        "Copy Mode"      c "copy-mode" \
        "Horizontal Split" h "split-window -h -c '#{pane_current_path}'" \
        "Vertical Split" v "split-window -v -c '#{pane_current_path}'" \
        "" \
        "#{?pane_marked,Unmark Pane,Mark Pane}" m "if-shell -F '#{pane_marked}' 'select-pane -M' 'select-pane -m'" \
        "Swap With Marked" s "swap-pane" \
        "Zoom"           z "resize-pane -Z" \
        "Kill Pane"      x "kill-pane"

      set -gu default-command
      set -g default-shell "$SHELL"

      set -sg escape-time 0
    '';
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    initExtra = ''
      # Source home-manager session variables
      if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      fi
    '';
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;

    envExtra = ''
      export LANG=en_US.UTF-8
      export LC_ALL=en_US.UTF-8
      export LC_CTYPE=en_US.UTF-8
    '';

    oh-my-zsh = {
      enable = true;
      theme = "fino";
      plugins = [
        "git"
        "npm"
        "history"
        "node"
        "rust"
      ];
    };

    shellAliases = {
      ta = "tmux new-session -As";
      ls = "lsd";
      wmm = "nvim '${homeDir}/obsidian/Main/Working Memory.md'";
      # Coding agents always run with the system node, even when nix-direnv
      # puts a project-specific node first in PATH.
      claude = ''PATH="${nodejsPackage}/bin:$PATH" claude'';
      codex = ''PATH="${nodejsPackage}/bin:$PATH" codex'';
      pi = ''PATH="${nodejsPackage}/bin:$PATH" pi'';
      ccc = "claude --dangerously-skip-permissions";
      ccx = "claude --settings ${homeDir}/.config/claude/gpt-proxy.json --dangerously-skip-permissions";
    };

    autosuggestion = {
      enable = true;
      highlight = "fg=#666666,bold";
    };

    history.ignoreAllDups = true;

    autocd = true;

    plugins = [{
      name = "zsh-fzf-history-search";
      src = pkgs.fetchFromGitHub {
        owner = "joshskidmore";
        repo = "zsh-fzf-history-search";
        rev = "d5a9730b5b4cb0b39959f7f1044f9c52743832ba";
        sha256 = "tQqIlkgIWPEdomofPlmWNEz/oNFA1qasILk4R5RWobY=";
      };
    }];

    initContent = lib.optionalString pkgs.stdenv.isDarwin ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
    '' + ''
      [ -f "$HOME/.secrets" ] && source "$HOME/.secrets"
    '';
  };

  pam.sessionVariables = config.home.sessionVariables // {
    LANGUAGE = "en_US:en";
    LANG = "en_US.UTF-8";
  };

  fonts.fontconfig.enable = true;

  programs.home-manager.enable = true;
}
