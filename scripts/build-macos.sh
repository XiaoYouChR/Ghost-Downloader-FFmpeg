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
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"   # absolute: we cd into $SRC below
cd "$SRC"

./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" \
  --disable-shared --enable-static \
  --extra-cflags="-Os $MIN" \
  --extra-ldflags="$MIN"

make -j"$(sysctl -n hw.ncpu)"
strip -x ffmpeg ffprobe 2>/dev/null || true
cp ffmpeg ffprobe "$OUT/"
echo "macOS ($(uname -m)) built -> $OUT"
ls -la "$OUT"
