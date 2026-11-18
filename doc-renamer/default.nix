# doc-renamer: sends bank receipts and slaughterhouse settlements from
# Downloads to Claude, which renames them and puts them in the output folder.
#
# Everything is in this folder:
#   default.nix     the launchd agent, the project files and the folders
#   doc-renamer.sh  the logic that the agent runs
#   CLAUDE.md       the instructions for Claude (also linked as AGENTS.md)
{ config, lib, pkgs, hostname, ... }:

let
  homeDir = config.home.homeDirectory;
  downloadsDir = "${homeDir}/Downloads";
  inboxDir = "${downloadsDir}/doc_renamer";
  outputDir = "${inboxDir}/output";
  # Claude runs here. It holds CLAUDE.md, the logs and the processed originals.
  projectPath = "dev/scratchpad/doc_renamer";
  projectDir = "${homeDir}/${projectPath}";
  logDir = "${projectDir}/logs";
  processedDir = "${projectDir}/processed";

  # Tesseract does not build without "eng".
  tesseractPortuguese = pkgs.tesseract.override { enableLanguages = [ "eng" "por" ]; };

  docRenamer = pkgs.writeShellApplication {
    name = "doc-renamer";
    runtimeInputs = with pkgs; [
      claude-code
      coreutils
      findutils
      gnugrep
      poppler-utils
      terminal-notifier
      tesseractPortuguese
    ];
    text = builtins.readFile ./doc-renamer.sh;
  };
in
lib.mkIf (hostname == "14m3") {
  home.file."${projectPath}/CLAUDE.md".source = ./CLAUDE.md;
  home.file."${projectPath}/AGENTS.md".source = ./CLAUDE.md;

  # launchd cannot start the agent when the folder of its log files is missing.
  home.activation.docRenamerFolders = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${lib.escapeShellArgs [ inboxDir outputDir logDir processedDir ]}
  '';

  launchd.agents.doc-renamer = {
    enable = true;
    config = {
      ProgramArguments = [ "${docRenamer}/bin/doc-renamer" ];
      WatchPaths = [ downloadsDir inboxDir ];
      ThrottleInterval = 10;
      Nice = 10;
      EnvironmentVariables = {
        DOWNLOADS_DIR = downloadsDir;
        INBOX_DIR = inboxDir;
        PROJECT_DIR = projectDir;
        # Without this, the Nix build of Claude Code cannot verify the API certificate.
        NODE_EXTRA_CA_CERTS = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        # For the tools that Claude starts. The script tools come from runtimeInputs.
        PATH = "${homeDir}/.nix-profile/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      StandardOutPath = "${logDir}/launchd-stdout.log";
      StandardErrorPath = "${logDir}/launchd-stderr.log";
    };
  };
}
