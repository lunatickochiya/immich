#!/usr/bin/env bash
#
# Apply the Immich fork patch series.
#
# Usage:
#   ./apply.sh [--no-ci] [--apply] [REPO]
#
#   --no-ci   skip 0005 (fork-only CI rewrite), for upstream PR work
#   --apply   use "git apply --3way" (leave changes uncommitted)
#             instead of "git am --3way" (create commits)
#   REPO      target git repository (default: current directory)
#
# Examples:
#   ./apply.sh ~/top/immich-new
#   ./apply.sh --no-ci ~/top/immich-new
#   ./apply.sh --apply ~/top/immich-new

set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MODE=am
SKIP_CI=0
REPO=

for arg in "$@"; do
  case "$arg" in
    --no-ci) SKIP_CI=1 ;;
    --apply) MODE=apply ;;
    -h|--help)
      sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "error: unknown option: $arg" >&2
      exit 2
      ;;
    *)
      if [ -n "$REPO" ]; then
        echo "error: multiple repository paths given" >&2
        exit 2
      fi
      REPO=$arg
      ;;
  esac
done

REPO=${REPO:-$(pwd)}
if ! git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: $REPO is not a git repository" >&2
  exit 2
fi

# git am/git apply resolve patch paths from their working directory,
# so always operate from the repository root (the script may be run
# from inside patches/immich-fork).
REPO_ROOT=$(git -C "$REPO" rev-parse --show-toplevel)

mapfile -t PATCHES < <(find "$HERE" -maxdepth 1 -name '[0-9][0-9][0-9][0-9]-*.patch' | sort)
if [ "${#PATCHES[@]}" -eq 0 ]; then
  echo "error: no numbered patches found next to $0" >&2
  exit 2
fi

if [ "$SKIP_CI" -eq 1 ]; then
  FILTERED=()
  for p in "${PATCHES[@]}"; do
    case "$(basename "$p")" in
      0005-*) continue ;;
    esac
    FILTERED+=("$p")
  done
  PATCHES=("${FILTERED[@]}")
fi

if [ "$MODE" = am ]; then
  if ! git -C "$REPO_ROOT" diff --quiet || ! git -C "$REPO_ROOT" diff --cached --quiet; then
    echo "error: working tree is not clean; commit/stash your changes first" >&2
    echo "       (or re-run with --apply to leave changes uncommitted)" >&2
    exit 2
  fi
fi

echo "Applying ${#PATCHES[@]} patch(es) to $REPO_ROOT using git $MODE --3way"
for p in "${PATCHES[@]}"; do
  echo "  -> $(basename "$p")"
  if [ "$MODE" = apply ]; then
    git -C "$REPO_ROOT" apply --3way "$p"
  else
    git -C "$REPO_ROOT" am --3way "$p"
  fi
done

echo
echo "Done."
if [ "$MODE" = am ]; then
  echo "Review with: git -C \"$REPO_ROOT\" log --oneline --decorate -6"
else
  echo "Review with: git -C \"$REPO_ROOT\" status"
fi
echo "If a conflict stops the series:"
echo "  git -C \"$REPO_ROOT\" status                  # edit conflicted files"
echo "  git -C \"$REPO_ROOT\" add <files>"
echo "  git -C \"$REPO_ROOT\" am --continue           # or: git am --abort"
