#!/usr/bin/env bash
# Linux build — runs NATIVELY on the matching runner (x64 on ubuntu-latest,
# arm64 on ubuntu-24.04-arm), so there is no cross-compilation. Fully static so
# the binary is self-contained (safe: zero external libs, network disabled).
#
# Usage: build-linux.sh <ffmpeg-src-dir> <out-bin-dir>

set -euo pipefail
SRC="${1:?ffmpeg-src-dir}"; OUT="${2:?out-bin-dir}"
source "$(dirname "$0")/configure-flags.sh"

mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"   # absolute: we cd into $SRC below
cd "$SRC"

./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" \
  --disable-shared --enable-static \
  --extra-cflags="-Os" \
  --extra-ldflags="-static -s"

make -j"$(nproc)"
strip ffmpeg ffprobe 2>/dev/null || true
cp ffmpeg ffprobe "$OUT/"
echo "linux ($(uname -m)) built -> $OUT"
ls -la "$OUT"
