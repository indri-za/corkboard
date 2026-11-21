#!/bin/sh
# Lint or format Sources and Tests with the toolchain swift-format.
# Usage: scripts/swift-format.sh [lint|format]
set -eu
cd "$(dirname "$0")/.."

mode="${1:-lint}"
case "$mode" in
  lint)
    xcrun swift-format lint --strict --recursive --configuration .swift-format Sources Tests
    ;;
  format)
    xcrun swift-format format --in-place --recursive --configuration .swift-format Sources Tests
    ;;
  *)
    echo "usage: scripts/swift-format.sh [lint|format]" >&2
    exit 2
    ;;
esac
