#!/usr/bin/env bash
# macOS build — runs NATIVELY on the matching runner (macos-13 = x86_64,
# macos-14 = arm64), so no cross-compilation. macOS has no fully-static libc, so
# the binary links libSystem dynamically (always present); everything else is
# static (zero external libs). Xcode command line tools provide clang + make.
#
# Usage: build-macos.sh <ffmpeg-src-dir> <out-bin-dir>

set -euo pipefail
SRC="${1:?ffmpeg-src-dir}"; OUT="${2:?out-bin-dir}"
source "$(dirname "$0")/configure-flags.sh"

MIN="-mmacosx-version-min=11.0"
ARCH="${ARCH:-$(uname -m)}"          # arm64 | x86_64
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"   # absolute: we cd into $SRC below
cd "$SRC"

# Both arches build on a single arm64 runner (macos-14); x86_64 is a clang -arch
# cross-build (Intel macOS runners are scarce/queued). clang targets both via -arch.
CROSS=()
[ "$ARCH" != "$(uname -m)" ] && CROSS=(--enable-cross-compile --arch="$ARCH")

./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" "${CROSS[@]}" \
  --disable-shared --enable-static \
  --extra-cflags="-Os -arch $ARCH $MIN" \
  --extra-ldflags="-arch $ARCH $MIN"

make -j"$(sysctl -n hw.ncpu)"
strip -x ffmpeg ffprobe 2>/dev/null || true
cp ffmpeg ffprobe "$OUT/"
echo "macOS ($ARCH) built -> $OUT"
ls -la "$OUT"
