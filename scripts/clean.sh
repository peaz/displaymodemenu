#!/usr/bin/env bash
set -euo pipefail

# Remove local build artifacts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build"

if [[ -d "$BUILD_DIR" ]]; then
  echo "Removing $BUILD_DIR ..."
  rm -rf "$BUILD_DIR"
  echo "Clean complete."
else
  echo "No build artifacts to remove at $BUILD_DIR."
fi
