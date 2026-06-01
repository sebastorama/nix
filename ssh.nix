{ ... }:

{
  programs.ssh = {
    enable = true;
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
