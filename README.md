# sebastorama nix-darwin configuration

1. Add Full Disk Access to 'Terminal.app'
2. Install [Homebrew](https://brew.sh/)
3. Install [Nix-Determinate Systems](https://github.com/DeterminateSystems/nix-installer)
4. Login in the Mac App Store
5. Clone this repo to `~/nix` with `git clone --recurse-submodules <repo-url> ~/nix`
6. Run `nix run nix-darwin -- switch --flake ~/nix#14m3`
7. Make some coffee (it'll take a while)
8. Profit

For existing clones, initialize submodules with `git submodule update --init --recursive`.
Private submodules require authenticated GitHub SSH access.

`~/.claude` resolves to `dotfiles/claude`; runtime state and secrets remain ignored by the child repository.

To update the Claude config, commit and push the child repository's `main` branch, then update and commit the parent repository's gitlink.

## Commands
