{ lib, pkgs, ... }:

{
  programs.ssh = {
    enable = true;
    includes = lib.optionals pkgs.stdenv.isDarwin [ "~/.orbstack/ssh/config" ];
    # Disable deprecated defaults and set ours explicitly
    enableDefaultConfig = false;
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
      };
      "14m3" = {
        hostname = "100.92.56.95";
        user = "sebastorama";
      };
    };
  };
}
