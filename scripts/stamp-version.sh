#!/bin/sh
# Write CorkboardVersion.current from the release tag.
# GitHub sets GITHUB_REF_NAME (v0.3.0). Locally, an exact tag on HEAD is used.
# With no tag, the committed fallback is left alone.
# Usage: scripts/stamp-version.sh
set -eu
cd "$(dirname "$0")/.."

file="Sources/CorkboardCore/CorkboardVersion.swift"
raw="${GITHUB_REF_NAME:-}"

if [ -z "$raw" ]; then
  if ! raw=$(git describe --tags --exact-match 2>/dev/null); then
    echo "stamp-version: no tag, leaving CorkboardVersion.current as committed"
    exit 0
  fi
fi

case "$raw" in
  v*|V*) version=$(printf '%s' "$raw" | cut -c2-) ;;
  *) version=$raw ;;
esac

if ! printf '%s' "$version" | grep -Eq '^[0-9]+([.][0-9]+){0,2}$'; then
  echo "stamp-version: '$raw' is not a numeric version like v0.3.0" >&2
  exit 1
fi

tmp=$(mktemp)
awk -v version="$version" '
  BEGIN { found = 0 }
  /^    public static let current = / {
    print "    public static let current = \"" version "\""
    found = 1
    next
  }
  { print }
  END { if (found == 0) exit 2 }
' "$file" > "$tmp"
mv "$tmp" "$file"
echo "stamp-version: CorkboardVersion.current = $version"
