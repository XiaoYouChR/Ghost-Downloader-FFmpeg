#!/usr/bin/env bash
# Windows + Linux lane, cross-compiled from a Linux container — the BtbN approach.
#
# We reuse BtbN/FFmpeg-Builds' toolchain rather than hand-rolling cross-compilers:
# its base image already provides mingw-w64 (win64/winarm64) and the native/musl
# linux toolchains plus a working FFmpeg cross-build harness. Our only change vs
# upstream is the configure flag set — we feed ${FFMPEG_CONFIGURE_FLAGS} instead
# of their defaults-gpl.sh.
#
# Two integration shapes (pick one in CI; documented in README):
#   A. Vendor BtbN: clone BtbN/FFmpeg-Builds, drop our flags into a custom
#      variant script (scripts.d/), and run their ./build.sh <target> <variant>.
#   B. Thin path (this script): use their cross toolchain image but call
#      ffmpeg ./configure directly with our flags. Simpler to read, but we own
#      the dependency/sysroot wiring that BtbN otherwise handles.
#
# Usage: build-windows-linux.sh <ffmpeg-src-dir> <out-bin-dir>
# Env:   TARGET = win64 | winarm64 | linux-x64 | linux-arm64
#
# This script implements shape B at skeleton level. The cross-prefix / sysroot
# lines below are TODO until validated against the chosen toolchain image — do not
# assume they are correct yet; CI must prove them via smoke-test.sh.

set -euo pipefail
SRC="${1:?ffmpeg-src-dir}"; OUT="${2:?out-bin-dir}"
source "$(dirname "$0")/configure-flags.sh"
TARGET="${TARGET:?set TARGET=win64|winarm64|linux-x64|linux-arm64}"

mkdir -p "$OUT"
COMMON=( "${FFMPEG_CONFIGURE_FLAGS[@]}" --disable-shared --enable-static --extra-cflags="-Os" )

case "$TARGET" in
  win64)
    TRIPLE=x86_64-w64-mingw32
    EXTRA=( --target-os=mingw32 --arch=x86_64 --enable-cross-compile
            --cross-prefix=${TRIPLE}- ) ; EXE=.exe ;;
  winarm64)
    TRIPLE=aarch64-w64-mingw32
    EXTRA=( --target-os=mingw32 --arch=aarch64 --enable-cross-compile
            --cross-prefix=${TRIPLE}- ) ; EXE=.exe ;;
  linux-x64)
    EXTRA=( --target-os=linux --arch=x86_64 ) ; EXE= ;;
  linux-arm64)
    TRIPLE=aarch64-linux-gnu
    EXTRA=( --target-os=linux --arch=aarch64 --enable-cross-compile
            --cross-prefix=${TRIPLE}- ) ; EXE= ;;
  *) echo "unknown TARGET: $TARGET" >&2; exit 1 ;;
esac

pushd "$SRC" >/dev/null
./configure "${COMMON[@]}" "${EXTRA[@]}" --prefix="$PWD/_install_${TARGET}"
make -j"$(nproc)"
# strip via the matching toolchain strip when cross, else host strip
STRIP="${TRIPLE:+${TRIPLE}-}strip"
command -v "$STRIP" >/dev/null && "$STRIP" "ffmpeg${EXE}" "ffprobe${EXE}" || strip "ffmpeg${EXE}" "ffprobe${EXE}" || true
cp "ffmpeg${EXE}" "ffprobe${EXE}" "$OUT/"
popd >/dev/null
echo "$TARGET built -> $OUT"
