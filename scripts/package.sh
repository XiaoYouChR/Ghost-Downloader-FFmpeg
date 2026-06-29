#!/usr/bin/env bash
# Package built binaries into a release asset + .sha256 sidecar.
#
# Asset names are VERSION-LESS and deterministic, so the app picks by exact name
# without reading the release tag. The release TAG (n8.1.1-gd1...) carries the
# version/provenance.
#
# Usage: package.sh <platform-arch> <bin-dir> <out-dir>
#   <platform-arch>: win64 | winarm64 | linux-x64 | linux-arm64 |
#                    macos-x64 | macos-arm64 | android-arm64
#   <bin-dir>: dir containing ffmpeg(.exe) + ffprobe(.exe)
#   <out-dir>: where ffmpeg-<platform-arch>.<ext> (+ .sha256) is written

set -euo pipefail

TARGET="${1:?usage: package.sh <platform-arch> <bin-dir> <out-dir>}"
BIN_DIR="${2:?bin-dir}"
OUT_DIR="${3:?out-dir}"
mkdir -p "$OUT_DIR"
# absolute: the zip path cd's into the staging dir, so a relative OUT_DIR would break.
OUT_DIR="$(cd "$OUT_DIR" && pwd)"

case "$TARGET" in
  win64|winarm64) EXT="zip"; SUFFIX=".exe" ;;
  linux-*|macos-*|android-*) EXT="tar.gz"; SUFFIX="" ;;
  *) echo "unknown target: $TARGET" >&2; exit 1 ;;
esac

ASSET="ffmpeg-${TARGET}.${EXT}"
STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT
cp "$BIN_DIR/ffmpeg${SUFFIX}" "$BIN_DIR/ffprobe${SUFFIX}" "$STAGE/"

# strip is done in the platform build scripts; here we only archive.
if [ "$EXT" = "zip" ]; then
  ( cd "$STAGE" && zip -9 -q "$OUT_DIR/$ASSET" "ffmpeg${SUFFIX}" "ffprobe${SUFFIX}" )
else
  tar -C "$STAGE" -czf "$OUT_DIR/$ASSET" "ffmpeg${SUFFIX}" "ffprobe${SUFFIX}"
fi

# sha256 sidecar (the app verifies this after download). sha256sum on Linux,
# shasum -a 256 on macOS — both emit "<hash>  <file>", which ChecksumStep parses.
( cd "$OUT_DIR"
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$ASSET" > "$ASSET.sha256"
  else shasum -a 256 "$ASSET" > "$ASSET.sha256"; fi )

echo "packaged: $OUT_DIR/$ASSET"
ls -la "$OUT_DIR/$ASSET" "$OUT_DIR/$ASSET.sha256"
cat "$OUT_DIR/$ASSET.sha256"
