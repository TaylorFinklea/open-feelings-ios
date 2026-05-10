#!/usr/bin/env bash
#
# Mirrors PRIVACY.md (on the current branch) to the orphan gh-pages
# branch via git plumbing — no working-tree changes, no checkout. After
# pushing, GitHub Pages rebuilds automatically and serves the new
# privacy policy at https://taylorfinklea.github.io/open-feelings-ios/.
#
# Usage:
#   scripts/publish_privacy.sh          # publish PRIVACY.md to gh-pages
#   scripts/publish_privacy.sh --dry    # show what would be published, don't push
#
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [[ ! -f PRIVACY.md ]]; then
    echo "PRIVACY.md not found at repo root" >&2
    exit 1
fi

DRY_RUN=0
if [[ "${1:-}" == "--dry" ]]; then
    DRY_RUN=1
fi

# Hash the privacy policy and the Jekyll config as git blobs.
INDEX_BLOB=$(git hash-object -w PRIVACY.md)
CONFIG_BLOB=$(printf 'title: Open Feelings\ndescription: Privacy policy and project links for the Open Feelings iOS app.\ntheme: jekyll-theme-minimal\n' \
    | git hash-object -w --stdin)

# Build the tree.
TREE=$({
    printf '100644 blob %s\tindex.md\n' "$INDEX_BLOB"
    printf '100644 blob %s\t_config.yml\n' "$CONFIG_BLOB"
} | git mktree)

# Find the current gh-pages tip (if any) — used as commit parent.
git fetch origin gh-pages --quiet 2>/dev/null || true
PARENT=$(git rev-parse origin/gh-pages 2>/dev/null || true)

# If the tree already matches, nothing to do.
if [[ -n "$PARENT" ]]; then
    EXISTING_TREE=$(git show -s --format=%T "$PARENT")
    if [[ "$TREE" == "$EXISTING_TREE" ]]; then
        echo "gh-pages already up to date with PRIVACY.md — nothing to do."
        exit 0
    fi
fi

MSG="Update gh-pages from PRIVACY.md ($(git rev-parse --short HEAD))"
if [[ -n "$PARENT" ]]; then
    COMMIT=$(printf '%s\n' "$MSG" | git commit-tree -p "$PARENT" "$TREE")
else
    COMMIT=$(printf '%s\n' "$MSG" | git commit-tree "$TREE")
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "Would push commit $COMMIT to origin/gh-pages"
    echo "Tree: $TREE"
    echo "Parent: ${PARENT:-<none — orphan>}"
    exit 0
fi

git update-ref refs/heads/gh-pages "$COMMIT"
git push origin gh-pages
echo
echo "Pushed gh-pages → $COMMIT"
echo "Site rebuilds in ~30-60s at:"
echo "  https://taylorfinklea.github.io/open-feelings-ios/"
