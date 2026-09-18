#!/usr/bin/env bash
# Put one pull request into its own worktree as unstaged work, so the review is
# done by staging each file you have read.
set -euo pipefail

force=false
pr=""

usage() {
  cat <<'EOF'
Usage: pr-review [-f] PR_NUMBER

Builds ~/.review_worktrees/<project>/<PR_NUMBER>/ as a git worktree.
The review branch starts at the merge base of the pull request and holds
every change of the pull request as unstaged work. Stage a file when you
have reviewed it; `git diff` then shows only the part that is left.

Options:
  -f, --force   Rebuild the worktree if it is already there.
  -h, --help    Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -f | --force) force=true ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      [[ -z $pr ]] || { echo 'Give one pull request number only.' >&2; exit 2; }
      pr=$1
      ;;
  esac
  shift
done

[[ -n $pr ]] || { usage >&2; exit 2; }
[[ $pr =~ ^[0-9]+$ ]] || { echo "Expected a pull request number, got: $pr" >&2; exit 2; }

git rev-parse --git-dir >/dev/null 2>&1 ||
  { echo 'Run this from inside a git repository.' >&2; exit 1; }
git remote get-url origin >/dev/null 2>&1 ||
  { echo "This repository has no 'origin' remote." >&2; exit 1; }

common_dir=$(git rev-parse --path-format=absolute --git-common-dir)
project=$(basename "$(dirname "$common_dir")")
worktree=$HOME/.review_worktrees/$project/$pr

echo "Reading pull request #$pr ..."
IFS=$'\t' read -r head_ref base_ref url title < <(
  gh pr view "$pr" --json headRefName,baseRefName,url,title \
    --jq '[.headRefName, .baseRefName, .url, .title] | @tsv'
)
[[ -n $head_ref && -n $base_ref ]] ||
  { echo "Could not read the branches of pull request #$pr." >&2; exit 1; }

echo "Fetching $base_ref and the head of the pull request ..."
git fetch --quiet origin "+refs/heads/$base_ref:refs/remotes/origin/$base_ref"
git fetch --quiet origin "pull/$pr/head"
head_sha=$(git rev-parse FETCH_HEAD)
base_sha=$(git rev-parse "refs/remotes/origin/$base_ref")
merge_base=$(git merge-base "$base_sha" "$head_sha")

if [[ -e $worktree ]]; then
  if [[ $force == false ]]; then
    echo "The worktree is already there: $worktree" >&2
    echo 'Use -f to rebuild it.' >&2
    exit 1
  fi
  git worktree remove --force "$worktree" 2>/dev/null || rm -rf "$worktree"
  git worktree prune
fi

# The review branch starts at the merge base. Name it after the base branch
# only while the merge base still is the tip of that branch; once the base
# branch has moved on, the short commit is the honest name.
if [[ $merge_base == "$base_sha" ]]; then
  base_is_at_tip=true
else
  base_is_at_tip=false
fi

if [[ $base_is_at_tip == true ]]; then
  base_label=${base_ref//\//-}
else
  base_label=${merge_base:0:8}
fi

review_branch="${head_ref//\//-}_review_$base_label"
mkdir -p "$(dirname "$worktree")"
git worktree add --quiet -B "$review_branch" "$worktree" "$merge_base"

# A squash merge writes the full change of the pull request into the index and
# the worktree. The reset moves it all back to unstaged.
git -C "$worktree" merge --squash "$head_sha" >/dev/null
git -C "$worktree" reset --quiet

# Record the new files as intent-to-add, so they show up in `git diff` next to
# the edited ones. Only the untracked files: `git add --all` would also stage
# the deletions, and a staged file means "reviewed" here.
untracked=$(git -C "$worktree" ls-files --others --exclude-standard)
if [[ -n $untracked ]]; then
  git -C "$worktree" ls-files --others --exclude-standard -z |
    xargs -0 git -C "$worktree" add --intent-to-add --
fi

file_count=$(git -C "$worktree" diff --name-only | wc -l | tr -d ' ')

if [[ $base_is_at_tip == true ]]; then
  base_line="$base_ref @ ${merge_base:0:8}, the tip"
else
  base_line="${merge_base:0:8}, where the pull request forked; $base_ref has moved on to ${base_sha:0:8}"
fi

cat <<EOF

PR #$pr  $title
$url
  base    $base_line
  head    $head_ref @ ${head_sha:0:8}
  branch  $review_branch
  files   $file_count unstaged

cd $worktree

  git diff             what is left to review
  git add <file>       mark a file as reviewed
  git diff --staged    what you have reviewed
EOF
