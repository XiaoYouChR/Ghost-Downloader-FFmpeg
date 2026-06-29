#!/usr/bin/env bash
# Android arm64 build via the NDK (replaces the hzw1199 prebuilt). Cross-compiled
# from a Linux runner. minSdk 21 (runs on 21+, incl. the app's 28). The unified
# NDK clang wrapper sets target+sysroot; binutils come from the llvm- cross-prefix.
# Executables are PIE (Android requirement) and link bionic dynamically (present
# on device) — NOT fully static. android/Dockerfile renames them to libffmpeg.so /
# libffprobe.so when packing the APK.
#
# Usage: build-android.sh <ffmpeg-src-dir> <out-bin-dir>
# Env:   ANDROID_NDK_ROOT (or ANDROID_NDK_LATEST_HOME), API=21 (default)

set -euo pipefail
SRC="${1:?ffmpeg-src-dir}"; OUT="${2:?out-bin-dir}"
source "$(dirname "$0")/configure-flags.sh"

NDK="${ANDROID_NDK_ROOT:-${ANDROID_NDK_LATEST_HOME:-}}"
[ -n "$NDK" ] || { echo "set ANDROID_NDK_ROOT" >&2; exit 1; }
API="${API:-21}"
TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
CC="$TOOLCHAIN/bin/aarch64-linux-android${API}-clang"
[ -x "$CC" ] || { echo "NDK clang not found: $CC" >&2; exit 1; }

mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"   # absolute: we cd into $SRC below
cd "$SRC"

./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" \
  --target-os=android --arch=aarch64 --cpu=armv8-a --enable-cross-compile \
  --cc="$CC" --cross-prefix="$TOOLCHAIN/bin/llvm-" \
  --disable-shared --enable-static --enable-pic \
  --extra-cflags="-Os -fPIE" \
  --extra-ldflags="-pie"

make -j"$(nproc)"
"$TOOLCHAIN/bin/llvm-strip" ffmpeg ffprobe 2>/dev/null || true
cp ffmpeg ffprobe "$OUT/"
echo "android arm64 (API $API) built -> $OUT"
file ffmpeg 2>/dev/null || true
ls -la "$OUT"
