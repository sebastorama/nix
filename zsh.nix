# Share the Node package selected by home.nix with the coding-agent aliases.
{ nodejsPackage }:
{ config, lib, pkgs, osConfig ? {}, ... }:

let
  homeDir = config.home.homeDirectory;
  # Build completion metadata from immutable package files, rather than scanning
  # the profiles and auditing their symlinks every time a terminal opens.
  zshCompletionFiles = pkgs.buildEnv {
    name = "zsh-completion-files";
    paths = config.home.packages ++ (osConfig.environment.systemPackages or []);
    pathsToLink = [ "/share/zsh" ];
    ignoreCollisions = true;
  };
  zshCompletionPath = [
    "${zshCompletionFiles}/share/zsh/site-functions"
    "${zshCompletionFiles}/share/zsh/vendor-completions"
    "${pkgs.zsh}/share/zsh/${pkgs.zsh.version}/functions"
  ];
  zshWidgetSetup = pkgs.writeText "prepare-zsh-widgets.zsh" ''
    fpath=(${lib.escapeShellArgs zshCompletionPath})
    autoload -Uz compinit
    compinit -C -d "$1/zcompdump"
    autoload -Uz up-line-or-beginning-search down-line-or-beginning-search edit-command-line
    zle -N up-line-or-beginning-search
    zle -N down-line-or-beginning-search
    zle -N edit-command-line
    FZF_CTRL_T_COMMAND=""
    FZF_ALT_C_COMMAND=""
    source ${pkgs.fzf}/share/fzf/key-bindings.zsh
    functions -m '__fzf*' fzf-history-widget > "$1/fzf-history.zsh"
    zcompile "$1/fzf-history.zsh"
    source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(fzf-history-widget)
    _zsh_autosuggest_bind_widgets
    {
      typeset -p _ZSH_AUTOSUGGEST_BIND_COUNTS
      for name in ''${(ok)functions}; do
        if [[ $name == _zsh_autosuggest_bound_* || $name == _zsh_autosuggest_orig_* ]]; then
          functions "$name"
        fi
      done
      zle -l -L
    } > "$1/autosuggest-bindings.zsh"
    zcompile "$1/autosuggest-bindings.zsh"
  '';
  zshPrepared = pkgs.runCommand "zsh-prepared" {
    nativeBuildInputs = [ pkgs.zsh ];
  } ''
    mkdir -p "$out/functions"
    ${pkgs.zoxide}/bin/zoxide init zsh > "$out/zoxide.zsh"
    ${pkgs.direnv}/bin/direnv hook zsh > "$out/direnv.zsh"
    cp ${pkgs.zsh}/share/zsh/${pkgs.zsh.version}/functions/compinit "$out/functions/compinit"
    zsh -ef <<EOF
    fpath=(${lib.escapeShellArgs zshCompletionPath})
    autoload -Uz compinit
    compinit -d "$out/zcompdump"
    zcompile "$out/zcompdump"
    zcompile "$out/functions/compinit"
    zcompile "$out/zoxide.zsh"
    zcompile "$out/direnv.zsh"
    EOF
    # The widget set is fixed by this configuration. Serialize the plugin's
    # bindings at build time instead of wrapping ~200 widgets on first precmd.
    TERM=xterm-256color zsh -efi ${zshWidgetSetup} "$out"
  '';
in
{
  # Home Manager creates HOME during activation. Avoid two processes per shell
  # just to mkdir that already-existing directory for the history file.
  home.file."./.zshrc".text = lib.mkForce (
    if config.programs.zsh.history.path == "${homeDir}/.zsh_history" then
      lib.replaceStrings
        [ ''mkdir -p "$(dirname "$HISTFILE")"'' ]
        [ "# The history directory is HOME and already exists." ]
        config.programs.zsh.initContent
    else config.programs.zsh.initContent
  );

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = false; # Hook is generated in zshPrepared at build time.
    nix-direnv.enable = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = false; # Hook is generated in zshPrepared at build time.
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    defaultKeymap = "emacs";
    completionInit = ''
      # Every autoload directory and the pre-audited dump live in the Nix store.
      # Package changes produce a new dump; no writable startup cache is needed.
      fpath=(${zshPrepared}/functions ${lib.escapeShellArgs zshCompletionPath})
      autoload -Uz compinit
      compinit -C -d ${zshPrepared}/zcompdump
    '';

    envExtra = ''
      # Keep /etc/zshenv and /etc/zprofile, but let Home Manager own the
      # interactive setup instead of repeating /etc/zshrc's defaults.
      NOSYSZSHRC=1
      export LANG=en_US.UTF-8
      export LC_ALL=en_US.UTF-8
      export LC_CTYPE=en_US.UTF-8
    '';

    shellGlobalAliases = {
      "..." = "../..";
      "...." = "../../..";
      "....." = "../../../..";
      "......" = "../../../../..";
    };

    shellAliases = {
      "-" = "cd -";
      "1" = "cd -1";
      "2" = "cd -2";
      "3" = "cd -3";
      "4" = "cd -4";
      "5" = "cd -5";
      "6" = "cd -6";
      "7" = "cd -7";
      "8" = "cd -8";
      "9" = "cd -9";
      md = "mkdir -p";
      rd = "rmdir";
      d = "dirs -v";
      l = "ls -lah";
      ll = "ls -lh";
      la = "ls -lAh";
      lsa = "ls -lah";
      h = "fc -l 1";
      hl = "fc -l 1 | less";
      hs = "fc -l 1 | grep";
      hsi = "fc -l 1 | grep -i";
      npmg = "npm i -g";
      npmS = "npm i -S";
      npmD = "npm i -D";
      npmF = "npm i -f";
      npmO = "npm outdated";
      npmU = "npm update";
      npmV = "npm -v";
      npmL = "npm list";
      npmL0 = "npm ls --depth=0";
      npmst = "npm start";
      npmt = "npm test";
      npmR = "npm run";
      npmP = "npm publish";
      npmI = "npm init";
      npmi = "npm info";
      npmSe = "npm search";
      npmrd = "npm run dev";
      npmrb = "npm run build";
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

    initContent = lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
    '' + ''
      [ -f "$HOME/.secrets" ] && source "$HOME/.secrets"
    '' + ''
      source ${zshPrepared}/zoxide.zsh
      source ${zshPrepared}/direnv.zsh
      source ${zshPrepared}/fzf-history.zsh
      zle -N fzf-history-widget

      # Native completion UI; Home Manager runs compinit once, before this.
      zmodload zsh/complist
      setopt auto_menu complete_in_word always_to_end
      unsetopt menu_complete flowcontrol
      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list \
        'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|=*' 'l:|=* r:|=*'
      zstyle ':completion:*' special-dirs true
      zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories

      # Cargo's generated script registers a completer rather than calling it.
      # Source it once so completion works on the first Tab press.
      source ${pkgs.cargo}/share/zsh/site-functions/_cargo
      _cargo_completion() {
        # This Cargo release panics when enumerating toolchains without rustup.
        # Its command list still works for the Nix-managed toolchain.
        if (( CURRENT == 2 && ! $+commands[rustup] )) && [[ $PREFIX != -* ]]; then
          local -a cargo_commands
          local name description
          while read -r name description; do
            [[ -n $name && $name != Installed ]] && cargo_commands+=("$name:$description")
          done < <(command cargo --list)
          _describe 'cargo command' cargo_commands
        else
          _clap_dynamic_completer_cargo "$@"
        fi
      }
      compdef _cargo_completion cargo

      # npm runs only when completing a command, never during startup.
      _npm_completion() {
        local IFS=$'\n'
        compadd -- $(COMP_CWORD=$((CURRENT-1)) COMP_LINE=$BUFFER \
          COMP_POINT=0 command npm completion -- "''${words[@]}" 2>/dev/null)
      }
      compdef _npm_completion npm

      setopt auto_pushd pushd_ignore_dups pushdminus hist_verify interactivecomments
      WORDCHARS=""
      mkcd() { mkdir -p -- "$1" && builtin cd -- "$1"; }
      take() { mkcd "$@"; }

      # Bind native editing widgets; Ctrl-R stays with the standalone fzf plugin.
      autoload -Uz up-line-or-beginning-search down-line-or-beginning-search edit-command-line
      zle -N up-line-or-beginning-search
      zle -N down-line-or-beginning-search
      zle -N edit-command-line
      bindkey '^[[A' up-line-or-beginning-search
      bindkey '^[[B' down-line-or-beginning-search
      bindkey '^[OA' up-line-or-beginning-search
      bindkey '^[OB' down-line-or-beginning-search
      bindkey '^[[H' beginning-of-line
      bindkey '^[[F' end-of-line
      bindkey '^[OH' beginning-of-line
      bindkey '^[OF' end-of-line
      bindkey '^[[1~' beginning-of-line
      bindkey '^[[4~' end-of-line
      bindkey '^[[3~' delete-char
      bindkey '^?' backward-delete-char
      bindkey '^[[3;5~' kill-word
      bindkey '^[[1;5C' forward-word
      bindkey '^[[1;5D' backward-word
      bindkey '^[[5~' up-line-or-history
      bindkey '^[[6~' down-line-or-history
      bindkey '^[[Z' reverse-menu-complete
      bindkey '^X^E' edit-command-line
      bindkey '^R' fzf-history-widget

      # Restore the bindings generated from the same pinned plugin and widgets.
      # No deferred first-keystroke setup or per-prompt rebinding is necessary.
      ZSH_AUTOSUGGEST_MANUAL_REBIND=1
      ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(fzf-history-widget)
      precmd_functions=(''${precmd_functions:#_zsh_autosuggest_start})
      source ${zshPrepared}/autosuggest-bindings.zsh

      # Refresh the branch and status before each prompt.
      unsetopt prompt_subst
      _update_git_prompt() {
        local branch git_status entry git_prompt="" staged="" unstaged=""
        branch=$(command git symbolic-ref --quiet --short HEAD 2>/dev/null) ||
          branch=$(command git rev-parse --short HEAD 2>/dev/null) || branch=""
        if [[ -n $branch ]]; then
          # Escape percent signs so branch names cannot introduce prompt escapes.
          git_prompt=" %F{239}(%F{magenta}''${branch//\%/%%}%f"
          # Porcelain's first two columns describe the index and working tree.
          # Avoid taking Git's optional index lock just to draw the prompt.
          if git_status=$(GIT_OPTIONAL_LOCKS=0 command git status --porcelain=v1 --untracked-files=normal 2>/dev/null); then
            for entry in "''${(@f)git_status}"; do
              [[ -z $entry ]] && continue
              if [[ ''${entry[1,2]} == '??' ]]; then
                unstaged="%F{yellow}!%f"
              else
                [[ ''${entry[1]} != ' ' ]] && staged="%F{green}+%f"
                [[ ''${entry[2]} != ' ' ]] && unstaged="%F{yellow}!%f"
              fi
            done
            if [[ -n $staged$unstaged ]]; then
              git_prompt+=" $staged$unstaged"
            else
              git_prompt+=" %F{green}✓%f"
            fi
          fi
          git_prompt+="%F{239})%f"
        fi
        PROMPT=$'%F{40}%n%F{239}@%F{${if pkgs.stdenv.hostPlatform.isLinux then "208" else "33"}}%m%F{239}:%B%F{226}%~%b%f'"$git_prompt"$'\n# '
      }
      autoload -Uz add-zsh-hook
      add-zsh-hook precmd _update_git_prompt
      RPROMPT=""
    '';
  };
}
