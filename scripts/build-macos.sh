#!/usr/bin/env bash
# macOS native build (runs on a GitHub `macos-14` runner). BtbN does not build
# macOS, so this lane is ours. Builds one arch per invocation (x86_64 or arm64);
# CI runs it twice and packages macos-x64 / macos-arm64 separately.
#
# Usage: build-macos.sh <ffmpeg-src-dir> <out-bin-dir>
# Env:   ARCH=arm64|x86_64 (default: host)

set -euo pipefail
SRC="${1:?ffmpeg-src-dir}"; OUT="${2:?out-bin-dir}"
source "$(dirname "$0")/configure-flags.sh"

ARCH="${ARCH:-$(uname -m)}"
case "$ARCH" in
  arm64|aarch64) ARCH=arm64 ;;
  x86_64|amd64)  ARCH=x86_64 ;;
  *) echo "unsupported macOS arch: $ARCH" >&2; exit 1 ;;
esac

mkdir -p "$OUT"
pushd "$SRC" >/dev/null

EXTRA="-Os -arch $ARCH -mmacosx-version-min=11.0"
CROSS=()
[ "$ARCH" != "$(uname -m | sed 's/aarch64/arm64/')" ] && CROSS=(--enable-cross-compile --arch="$ARCH")

./configure \
  "${FFMPEG_CONFIGURE_FLAGS[@]}" \
  --prefix="$PWD/_macos_install" \
  --target-os=darwin \
  "${CROSS[@]}" \
  --disable-shared --enable-static \
  --extra-cflags="$EXTRA" \
  --extra-ldflags="-arch $ARCH -mmacosx-version-min=11.0"

make -j"$(sysctl -n hw.ncpu)"
strip -x ffmpeg ffprobe || true
cp ffmpeg ffprobe "$OUT/"
popd >/dev/null

# Gatekeeper note: the binaries we ship are unsigned. The APP clears the
# com.apple.quarantine xattr after download (InstallStep.removeQuarantine). If we
# later want signed/notarized binaries, add codesign here.
echo "macOS $ARCH built -> $OUT"
