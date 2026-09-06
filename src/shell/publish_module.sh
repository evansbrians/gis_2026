#!/usr/bin/env bash
# publish_module.sh — render ONE module (or named lessons within it) via
# src/r/render_module.R's render_module(), then push just that content to
# GitHub Pages, leaving every other already-published module and lesson
# untouched.
#
# This uses render_module()'s own output convention:
# modules/<module>/<lesson_name>/index.html — NOT a separate out/
# directory. Do not set project: output-dir in _quarto.yml; it
# conflicts with how render_module() locates its own render output.
#
# Prerequisite: run setup_gh_pages.sh once first (creates the gh-pages
# branch + sibling worktree).
#
# Can live anywhere inside the repo (e.g. src/shell/) — it locates the
# repo root itself via git.
# Must be executable: chmod +x publish_module.sh
#
# Usage:
#   # Every lesson in a module:
#   src/shell/publish_module.sh module_0
#
#   # One or more specific lessons (with or without the .qmd extension):
#   src/shell/publish_module.sh module_2 2.1_subsetting_and_extraction
#   src/shell/publish_module.sh module_2 2.1_subsetting_and_extraction 2.2_mutation

set -euo pipefail

MODULE="${1:-}"
if [[ -z "$MODULE" ]]; then
  echo "Usage: $0 <module_name> [lesson_name ...]   e.g. $0 module_2 2.1_subsetting_and_extraction" >&2
  exit 1
fi
shift

# Any remaining arguments name individual lessons. Strip a trailing .qmd
# so that both forms work, matching render_module()'s own behavior.
LESSONS=()
for lesson in "$@"; do
  LESSONS+=("${lesson%.qmd}")
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
WORKTREE="$REPO_ROOT/../gis_2026-pages"
SRC_DIR="modules/$MODULE"

if [[ ! -d "$REPO_ROOT/$SRC_DIR" ]]; then
  echo "No such module directory: $SRC_DIR" >&2
  exit 1
fi

if [[ ! -d "$WORKTREE" ]]; then
  echo "gh-pages worktree not found at $WORKTREE — run setup_gh_pages.sh first." >&2
  exit 1
fi

cd "$REPO_ROOT"

# Fail early on a lesson name that does not exist, rather than rendering
# the rest and reporting nothing to publish at the end.
for lesson in "${LESSONS[@]+"${LESSONS[@]}"}"; do
  if [[ ! -f "$SRC_DIR/$lesson.qmd" ]]; then
    echo "No such lesson: $SRC_DIR/$lesson.qmd" >&2
    exit 1
  fi
done

if [[ ${#LESSONS[@]} -eq 0 ]]; then
  echo "==> Rendering $MODULE via render_module() ..."
  Rscript -e "source('src/r/render_module.R'); render_module('$MODULE')"
else
  echo "==> Rendering ${#LESSONS[@]} lesson(s) in $MODULE via render_module() ..."
  R_LESSONS="c($(printf "'%s'," "${LESSONS[@]}" | sed 's/,$//'))"
  Rscript -e "source('src/r/render_module.R'); render_module('$MODULE', .lessons = $R_LESSONS)"
fi

# render_module() creates one directory per lesson directly under
# modules/<module>/, each containing an index.html. That's exactly
# (and only) what should be published — .qmd sources, function_tables/,
# etc. are plain files or other dirs, so they're naturally excluded.
# When lessons were named, publish only those, so that a module folder
# holding other rendered lessons is left alone.
LESSON_DIRS=()
if [[ ${#LESSONS[@]} -eq 0 ]]; then
  while IFS= read -r dir; do
    LESSON_DIRS+=("$dir")
  done < <(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d -exec test -e "{}/index.html" \; -print)
else
  for lesson in "${LESSONS[@]}"; do
    if [[ -e "$SRC_DIR/$lesson/index.html" ]]; then
      LESSON_DIRS+=("$SRC_DIR/$lesson")
    fi
  done
fi

if [[ ${#LESSON_DIRS[@]} -eq 0 ]]; then
  echo "No rendered lesson folders (with index.html) found under $SRC_DIR." >&2
  exit 1
fi

echo "==> Syncing ${#LESSON_DIRS[@]} lesson(s) into the gh-pages worktree ..."
mkdir -p "$WORKTREE/$MODULE"
for dir in "${LESSON_DIRS[@]}"; do
  lesson_name="$(basename "$dir")"
  rsync -av --delete "$dir/" "$WORKTREE/$MODULE/$lesson_name/"
done

cd "$WORKTREE"

# Stage only what was published, so that naming a lesson never sweeps up
# an unrelated change sitting in the worktree.
for dir in "${LESSON_DIRS[@]}"; do
  git add "$MODULE/$(basename "$dir")"
done

if git diff --cached --quiet; then
  echo "==> No changes — nothing to publish."
  exit 0
fi

if [[ ${#LESSONS[@]} -eq 0 ]]; then
  git commit -m "Publish $MODULE"
else
  git commit -m "Publish $MODULE: ${LESSONS[*]}"
fi

git push origin gh-pages

echo "==> Done. Every other module and lesson on gh-pages is untouched."
