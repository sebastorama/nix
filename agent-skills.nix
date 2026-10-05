# Matt Pocock's agent skills (github:mattpocock/skills) for Claude Code,
# Codex and pi. The repo is a plain tree of skills/<group>/<name>/SKILL.md;
# this module flattens it to <name>/, renames each skill to mp-<name> in
# its frontmatter, and links it where each tool looks.
{ config, lib, pkgs, inputs, ... }:

let
  homeDir = config.home.homeDirectory;

  # Only the groups upstream ships in its plugin.json. deprecated/, misc/ and
  # in-progress/ are left out.
  groups = [ "engineering" "productivity" ];

  # Codex and pi take the skill name from the SKILL.md frontmatter, so the
  # prefix has to go there. Copy instead of symlink so the file is editable.
  # The directory keeps its plain name; Claude Code links it as mp:<name>.
  skills = pkgs.runCommand "mattpocock-skills" { } ''
    mkdir -p "$out"
    for group in ${lib.concatStringsSep " " groups}; do
      for skill in ${inputs.mattpocock-skills}/skills/$group/*/; do
        name="$(basename "$skill")"
        cp -r "$skill" "$out/$name"
        chmod -R u+w "$out/$name"
        sed -i "s/^name: .*/name: mp-$name/" "$out/$name/SKILL.md"
      done
    done
  '';
in
{
  # Codex and pi both discover skills here.
  home.file.".agents/skills".source = skills;

  # Claude Code only reads ~/.claude/skills, and ~/.claude is an out-of-store
  # symlink into dotfiles/claude, so home.file cannot nest entries under it.
  # Link each skill by hand as mp:<name> so they show up as /mp:<name>;
  # that repo's .gitignore skips skills/.
  home.activation.linkMattPocockSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dest="${homeDir}/.claude/skills"
    run mkdir -p "$dest"
    run find "$dest" -maxdepth 1 -type l -lname '/nix/store/*-mattpocock-skills/*' -delete
    for skill in ${skills}/*/; do
      run ln -sfn "$skill" "$dest/mp:$(basename "$skill")"
    done
  '';
}
