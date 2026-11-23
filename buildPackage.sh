#!/bin/bash
#
# Script to create a zipped tar (.tgz) of this package for use in Paperpile `desktop`.
#
# It checks out the `desktop-tgz` branch, packs the package using `npm pack`, commits the new
# .tgz file to Git and creates a tag to have a stable reference we can then use in `desktop`.
#
# Run this on macOS or Linux - packing on Windows would drop the executable bit (see README).
#
# The `desktop-tgz` branch is only used for automatic .tgz publishing and is always overwritten
# by this script.
set -euo pipefail

TGZ_DIR="tgz"
BRANCH=$(git rev-parse --abbrev-ref HEAD)
TGZ_BRANCH="desktop-tgz"

if [ "$BRANCH" != "main" ]; then
  echo "❌ Script must be run on the 'main' branch. Current branch is '$BRANCH'."
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "❌ Uncommitted changes detected on '$BRANCH'. Commit or stash them first."
  exit 1
fi

echo "Checking out branch ${TGZ_BRANCH}..."
git branch -f "$TGZ_BRANCH" "$BRANCH"
git checkout "$TGZ_BRANCH"

mkdir -p "$TGZ_DIR"

echo "Packing package..."
PACKAGE_TGZ=$(npm pack . --pack-destination "$TGZ_DIR")
echo "✓ $PACKAGE_TGZ"
echo

PACKAGE_VERSION="$(node -p "require('./package.json').version")"
TAG="desktop-v$PACKAGE_VERSION"

EXISTING_TAGS=$(git tag -l "$TAG*")
# tag already exists, append -1, -2, -3...
if [ -n "$EXISTING_TAGS" ]; then
  # Filter to only suffixed tags (e.g. desktop-v10.13.0-1), extract the numeric suffix
  EXISTING_SUFFIXES=$(echo "$EXISTING_TAGS" | grep "^${TAG}-" | sed "s/^${TAG}-//" | sort -n || true)

  if [ -z "$EXISTING_SUFFIXES" ]; then
      NEXT_SUFFIX=1
  else
      LAST_SUFFIX=$(echo "$EXISTING_SUFFIXES" | tail -n1)
      NEXT_SUFFIX=$((LAST_SUFFIX + 1))
  fi

  TAG="${TAG}-${NEXT_SUFFIX}"
fi

echo "Adding ${TGZ_DIR} to Git and committing..."
git add "$TGZ_DIR"
git commit -m "Pack .tgz package for $TAG"
git push -f origin "$TGZ_BRANCH"

echo "Creating tag: $TAG..."
git tag "$TAG"
git push origin "$TAG"

echo
echo "📦 Download URL for your .tgz package:"
for TGZ_PATH in "$TGZ_DIR"/*.tgz; do
  echo "  https://raw.githubusercontent.com/Paperpile/realm-js/refs/tags/$TAG/$TGZ_PATH"
done

git checkout "$BRANCH"
