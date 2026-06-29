#!/usr/bin/env bash
# Single source of truth for the minimal FFmpeg feature set.
#
# Every platform build script sources this file and uses ${FFMPEG_CONFIGURE_FLAGS[@]}.
# The set is intentionally narrow: Ghost Downloader never transcodes audio/video.
# It only stream-copies, muxes, decrypts AES-128, reads duration with ffprobe, and
# (for yt-dlp) converts a webp thumbnail into an mp4-compatible image.
#
# This is the FIRST DRAFT. The CI smoke tests (scripts/smoke-test.sh) are what turn
# it into a proven set: a missing demuxer/parser/bsf must fail CI, not a user download.
# When a smoke test fails for a missing component, add it HERE, never per-platform.

set -euo pipefail

# --- licensing: LGPLv3, zero GPL / nonfree ---
LICENSE_FLAGS=(
  --disable-gpl
  --disable-nonfree
  --enable-version3
)

# --- programs / size / footprint ---
BASE_FLAGS=(
  --disable-everything
  --enable-ffmpeg
  --enable-ffprobe
  --disable-ffplay
  --enable-small
  --disable-debug
  --disable-doc
  --disable-htmlpages --disable-manpages --disable-podpages --disable-txtpages
  --disable-avdevice
  # Zero external libraries — guarantees identical, trivial cross-builds on every
  # target (no zlib/openssl/x264/... to provision per toolchain). The crypto
  # protocol / HLS AES-128 use libavutil's built-in AES, so no openssl is needed.
  --disable-autodetect
  --disable-x86asm
  # NOTE (riskiest flag): network is OFF. In this app, segments are pre-downloaded
  # by N_m3u8DL-RE / yt-dlp and ffmpeg only ever touches local files + pipes, so
  # dropping TLS/HTTP saves a lot of size. If a future path feeds ffmpeg an http(s)
  # URL directly (e.g. yt-dlp `--downloader ffmpeg`, live HLS over http), flip this
  # to `--enable-network` + protocols http,https,tls and rebuild. The
  # smoke-test "hls-over-http" case (disabled by default) guards this.
  --disable-network
)

# --- protocols: local IO + AES-128 + segment piping/concat ---
PROTOCOL_FLAGS=(
  --enable-protocol=file
  --enable-protocol=pipe
  --enable-protocol=fd
  --enable-protocol=crypto   # HLS AES-128
  --enable-protocol=data     # data: URIs (init segments, keys)
  --enable-protocol=concat
  --enable-protocol=concatf
)

# --- demuxers: every container/segment shape we may read ---
DEMUXER_FLAGS=(
  --enable-demuxer=mov            # mp4 / m4a / m4s (fmp4) / mov
  --enable-demuxer=matroska       # mkv + webm
  --enable-demuxer=mpegts
  --enable-demuxer=hls
  --enable-demuxer=dash
  --enable-demuxer=flv
  --enable-demuxer=aac
  --enable-demuxer=ac3
  --enable-demuxer=eac3
  --enable-demuxer=mp3
  --enable-demuxer=flac
  --enable-demuxer=ogg
  --enable-demuxer=wav
  --enable-demuxer=h264
  --enable-demuxer=hevc
  --enable-demuxer=concat
  --enable-demuxer=ffmetadata     # --embed-metadata / --embed-chapters readback
  # thumbnail sources (image2 = file by ext; image_*_pipe = probe by content)
  --enable-demuxer=image2
  --enable-demuxer=image2pipe
  --enable-demuxer=image_png_pipe
  --enable-demuxer=image_webp_pipe
  --enable-demuxer=image_jpeg_pipe
  --enable-demuxer=mjpeg
  # subtitle inputs (sidecar today; cheap headroom for future embed-subs)
  --enable-demuxer=srt
  --enable-demuxer=webvtt
  --enable-demuxer=ass
)

# --- muxers: mp4/mkv/webm outputs, metadata, thumbnail image out ---
MUXER_FLAGS=(
  --enable-muxer=mp4
  --enable-muxer=mov
  --enable-muxer=ipod            # m4a / m4b
  --enable-muxer=matroska
  --enable-muxer=webm
  --enable-muxer=mpegts
  --enable-muxer=ffmetadata
  --enable-muxer=image2
  --enable-muxer=mjpeg
  --enable-muxer=webp
  --enable-muxer=data
)

# --- decoders: ONLY for thumbnail conversion (stream copy needs none) ---
# png/zlib is deliberately excluded to keep the build dependency-free; the app
# passes yt-dlp `--convert-thumbnails jpg`, so source thumbnails (webp/jpg) decode
# here and re-encode as mjpeg. webp lossy = VP8 intra, so vp8 is required.
DECODER_FLAGS=(
  # thumbnail decode (webp lossy = VP8 intra)
  --enable-decoder=webp
  --enable-decoder=vp8
  --enable-decoder=mjpeg
  # audio decoders: required so remux (-c copy) can read codec parameters
  # (sample rate, channels) from raw/ADTS audio in TS/HLS, where the container
  # carries no extradata. Without them, mp4/mkv muxing fails "sample rate not
  # set" — which would break real m3u8 / bilibili / yt-dlp remuxing too.
  --enable-decoder=aac
  --enable-decoder=ac3
  --enable-decoder=eac3
  --enable-decoder=mp3
  --enable-decoder=mp3float
  --enable-decoder=flac
  --enable-decoder=opus
  --enable-decoder=vorbis
)

# --- encoders: ONLY mjpeg (jpg) for the thumbnail conversion target ---
ENCODER_FLAGS=(
  --enable-encoder=mjpeg
)

# --- parsers: keep copy/probe from failing to read codec parameters (cheap) ---
PARSER_FLAGS=(
  --enable-parser=h264
  --enable-parser=hevc
  --enable-parser=aac
  --enable-parser=aac_latm
  --enable-parser=ac3
  --enable-parser=mpegaudio
  --enable-parser=flac
  --enable-parser=opus
  --enable-parser=vorbis
  --enable-parser=vp8
  --enable-parser=vp9
  --enable-parser=av1
  --enable-parser=mjpeg
  --enable-parser=webp
)

# --- bitstream filters: the remux glue ---
BSF_FLAGS=(
  --enable-bsf=h264_mp4toannexb
  --enable-bsf=hevc_mp4toannexb
  --enable-bsf=aac_adtstoasc
  --enable-bsf=vp9_superframe
  --enable-bsf=vp9_raw_reorder
  --enable-bsf=extract_extradata
)

FFMPEG_CONFIGURE_FLAGS=(
  "${LICENSE_FLAGS[@]}"
  "${BASE_FLAGS[@]}"
  "${PROTOCOL_FLAGS[@]}"
  "${DEMUXER_FLAGS[@]}"
  "${MUXER_FLAGS[@]}"
  "${DECODER_FLAGS[@]}"
  "${ENCODER_FLAGS[@]}"
  "${PARSER_FLAGS[@]}"
  "${BSF_FLAGS[@]}"
)

export FFMPEG_CONFIGURE_FLAGS
