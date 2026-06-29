#!/usr/bin/env bash
# Android arm64 build via the NDK. Replaces the hzw1199 prebuilt with our minimal set.
# Targets minSdk 28, NDK r28 (match Ghost Downloader's android/Dockerfile).
# No MediaCodec / HW decoders: the app only -c copy, never decodes on device.
#
# Usage: build-android.sh <ffmpeg-src-dir> <out-bin-dir>
# Env:   ANDROID_NDK_ROOT, API=28 (default), ABI=arm64-v8a (default)

set -euo pipefail
SRC="${1:?ffmpeg-src-dir}"; OUT="${2:?out-bin-dir}"
source "$(dirname "$0")/configure-flags.sh"

: "${ANDROID_NDK_ROOT:?set ANDROID_NDK_ROOT}"
API="${API:-28}"
HOST_TAG="linux-x86_64"
TOOLCHAIN="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/$HOST_TAG"
CROSS_PREFIX="$TOOLCHAIN/bin/llvm-"
CC="$TOOLCHAIN/bin/aarch64-linux-android${API}-clang"

mkdir -p "$OUT"
pushd "$SRC" >/dev/null

./configure \
  "${FFMPEG_CONFIGURE_FLAGS[@]}" \
  --prefix="$PWD/_android_install" \
  --target-os=android \
  --arch=aarch64 \
  --cpu=armv8-a \
  --enable-cross-compile \
  --cc="$CC" \
  --cxx="$TOOLCHAIN/bin/aarch64-linux-android${API}-clang++" \
  --ar="${CROSS_PREFIX}ar" \
  --ranlib="${CROSS_PREFIX}ranlib" \
  --strip="${CROSS_PREFIX}strip" \
  --nm="${CROSS_PREFIX}nm" \
  --sysroot="$TOOLCHAIN/sysroot" \
  --enable-pic \
  --disable-shared --enable-static \
  --extra-cflags="-Os -fPIC -DANDROID" \
  --extra-ldflags="-fPIE -pie"

make -j"$(nproc)"
"${CROSS_PREFIX}strip" ffmpeg ffprobe || true
cp ffmpeg ffprobe "$OUT/"
popd >/dev/null

# NOTE: android/Dockerfile renames these to libffmpeg.so / libffprobe.so when it
# packs them into the APK; we ship plain ffmpeg/ffprobe in the tar.gz.
echo "android arm64 built -> $OUT"
