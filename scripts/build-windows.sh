#!/usr/bin/env bash
# Windows build — cross-compiled from a Linux runner. Zero external libs, so the
# only toolchain needed is a C compiler:
#   win64    : mingw-w64 from apt (gcc-mingw-w64-x86-64)
#   winarm64 : llvm-mingw (mstorsjo) on PATH (aarch64-w64-mingw32-clang)
# Fully static -> a single self-contained .exe (no libgcc/libwinpthread DLLs).
#
# Usage: build-windows.sh <ffmpeg-src-dir> <out-bin-dir>
# Env:   TARGET = win64 | winarm64

set -euo pipefail
SRC="${1:?ffmpeg-src-dir}"; OUT="${2:?out-bin-dir}"
source "$(dirname "$0")/configure-flags.sh"
TARGET="${TARGET:?set TARGET=win64|winarm64}"

case "$TARGET" in
  win64)    CROSS=x86_64-w64-mingw32-  ; ARCH=x86_64  ; CC=${CROSS}gcc ;;
  winarm64) CROSS=aarch64-w64-mingw32- ; ARCH=aarch64 ; CC=${CROSS}clang ;;
  *) echo "unknown TARGET: $TARGET" >&2; exit 1 ;;
esac

mkdir -p "$OUT"
cd "$SRC"

./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" \
  --target-os=mingw32 --arch="$ARCH" --enable-cross-compile \
  --cross-prefix="$CROSS" --cc="$CC" \
  --disable-shared --enable-static \
  --extra-cflags="-Os" \
  --extra-ldflags="-static -s"

make -j"$(nproc)"
"${CROSS}strip" ffmpeg.exe ffprobe.exe 2>/dev/null || true
cp ffmpeg.exe ffprobe.exe "$OUT/"
echo "$TARGET built -> $OUT"
ls -la "$OUT"
