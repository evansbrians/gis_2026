#!/usr/bin/env bash
# publish_standalone.sh — publish ONE rendered standalone doc (e.g.
# logistics/index.html, produced by render_standalone(), see
# src/r/render_standalone.R) to the gh-pages branch, mirroring
# publish_module.sh's per-module approach for docs that live outside
# modules/.
#
# Prerequisite: run setup_gh_pages.sh once first (creates the gh-pages
# branch + sibling worktree).
#
# Can live anywhere inside the repo (e.g. src/shell/) — it locates the
# repo root itself via git.
# Must be executable: chmod +x publish_standalone.sh
#
# Usage:
#   src/shell/publish_standalone.sh logistics/index.html

set -euo pipefail

DOC_PATH="${1:-}"
if [[ -z "$DOC_PATH" ]]; then
  echo "Usage: $0 <path/to/index.html>   e.g. $0 logistics/index.html" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
WORKTREE="$REPO_ROOT/../gis_2026-pages"

if [[ ! -f "$REPO_ROOT/$DOC_PATH" ]]; then
  echo "No rendered file at $DOC_PATH — render it first, e.g.:" >&2
  echo "  Rscript -e \"source('src/r/render_standalone.R'); render_standalone('...')\"" >&2
  exit 1
fi

if [[ ! -d "$WORKTREE" ]]; then
  echo "gh-pages worktree not found at $WORKTREE — run setup_gh_pages.sh first." >&2
  exit 1
fi

cd "$REPO_ROOT"

echo "==> Syncing $DOC_PATH into the gh-pages worktree ..."
mkdir -p "$WORKTREE/$(dirname "$DOC_PATH")"
cp "$DOC_PATH" "$WORKTREE/$DOC_PATH"

cd "$WORKTREE"
git add "$DOC_PATH"

if git diff --cached --quiet; then
  echo "==> No changes for $DOC_PATH — nothing to publish."
  exit 0
fi

git commit -m "Publish $DOC_PATH"
git push origin gh-pages

echo "==> Done — $DOC_PATH is live."
