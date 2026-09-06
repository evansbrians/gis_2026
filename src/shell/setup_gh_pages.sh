#!/usr/bin/env bash
# setup_gh_pages.sh — one-time setup for per-module GitHub Pages publishing.
#
# Creates a gh-pages branch if one doesn't exist yet, and checks it out as
# a sibling git worktree so you can publish without ever switching branches
# on your working copy of main. Can live anywhere inside the repo (e.g.
# src/shell/) — it locates the repo root itself via git.
#
# Must be executable: chmod +x setup_gh_pages.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
WORKTREE="$REPO_ROOT/../gis_2026-pages"

cd "$REPO_ROOT"

if git ls-remote --exit-code --heads origin gh-pages >/dev/null 2>&1; then
  echo "==> gh-pages already exists on the remote."
  if [[ ! -d "$WORKTREE" ]]; then
    echo "==> Adding gh-pages worktree at $WORKTREE ..."
    git worktree add "$WORKTREE" gh-pages
  else
    echo "==> gh-pages worktree already exists at $WORKTREE"
  fi
else
  echo "==> Creating empty gh-pages branch as a fresh worktree (no rm -rf involved) ..."
  git worktree add --orphan -b gh-pages "$WORKTREE"
  (
    cd "$WORKTREE"
    git commit --allow-empty -m "Initialize gh-pages"
    git push -u origin gh-pages
  )
fi

cat <<EOF

==> Setup complete. Remaining one-time step:

  On GitHub: Settings -> Pages -> Source: "Deploy from a branch" ->
  branch "gh-pages", folder "/ (root)".

After that, publish any module with (adjust the path to wherever you put
the script):

  src/shell/publish_module.sh module_0

EOF
