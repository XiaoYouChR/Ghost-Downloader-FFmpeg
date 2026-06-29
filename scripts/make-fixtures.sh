#!/usr/bin/env bash
# Generate the tiny smoke-test fixtures with a FULL ffmpeg (needs libx264, aac,
# eac3, libwebp). Run once, commit the outputs; CI only consumes them.
#
# Usage: make-fixtures.sh [source-video]
#   source-video : optional. Its video stream is used (scaled tiny). If omitted
#                  (or it has no usable video), a synthetic testsrc is used.
#   Audio is always synthetic (a 0.5s sine) so fixtures need no real audio.
#
# Everything is cut to ~0.5s at <=160px so each file is a few KB.

set -euo pipefail
HERE="$(cd "$(dirname "$0")/../tests/fixtures" && pwd)"
SRC="${1:-}"
DUR=0.5

video_in=(-f lavfi -i "testsrc2=size=160x90:rate=15:duration=$DUR")
if [ -n "$SRC" ] && ffprobe -v error -select_streams v:0 -show_entries stream=codec_type \
     -of csv=p=0 "$SRC" 2>/dev/null | grep -q video; then
  echo "using video from: $SRC"
  video_in=(-t "$DUR" -i "$SRC")
else
  echo "using synthetic testsrc2 video"
fi

cd "$HERE"
mkdir -p encrypted fmp4

echo "== base.mp4 (tiny h264 + sine aac) =="
ffmpeg -hide_banner -v error -y \
  "${video_in[@]}" \
  -f lavfi -i "sine=frequency=440:duration=$DUR" \
  -map 0:v:0 -map 1:a:0 -t "$DUR" \
  -vf "scale=160:-2,format=yuv420p" \
  -c:v libx264 -preset ultrafast -g 15 \
  -c:a aac -b:a 32k -shortest base.mp4

echo "== video.h264.mp4 / audio.aac.m4a (stream copy) =="
ffmpeg -hide_banner -v error -y -i base.mp4 -map 0:v -c copy video.h264.mp4
ffmpeg -hide_banner -v error -y -i base.mp4 -map 0:a -c copy audio.aac.m4a

echo "== segment.ts (mpegts, aac in adts) =="
ffmpeg -hide_banner -v error -y -i base.mp4 -c copy -f mpegts segment.ts

echo "== fmp4/stream.mp4 (fragmented) =="
ffmpeg -hide_banner -v error -y -i base.mp4 -c copy \
  -movflags +frag_keyframe+empty_moov+default_base_moof fmp4/stream.mp4

echo "== audio.eac3.mkv =="
ffmpeg -hide_banner -v error -y -i base.mp4 -map 0:a -c:a eac3 -b:a 128k -vn audio.eac3.mkv

echo "== thumb.webp (lossy -> exercises webp+vp8 decode) =="
ffmpeg -hide_banner -v error -y -i base.mp4 -frames:v 1 \
  -vf "scale=96:-2" -c:v libwebp -lossless 0 -q:v 75 thumb.webp

echo "== encrypted/ HLS AES-128 =="
head -c 16 /dev/urandom > encrypted/key.bin
# keyinfo: line1 = URI written into the playlist; line2 = key file ffmpeg reads
# (relative to cwd = the fixtures dir, so it is portable across Win/Linux/macOS).
printf 'key.bin\nencrypted/key.bin\n' > encrypted/keyinfo
ffmpeg -hide_banner -v error -y -i base.mp4 -c copy \
  -hls_time 10 -hls_playlist_type vod -hls_segment_type mpegts \
  -hls_key_info_file encrypted/keyinfo \
  -hls_segment_filename "encrypted/seg%d.ts" encrypted/index.m3u8
rm -f encrypted/keyinfo

echo "== meta.ffmeta =="
cat > meta.ffmeta <<'EOF'
;FFMETADATA1
title=Ghost Downloader smoke fixture
artist=GD3
[CHAPTER]
TIMEBASE=1/1000
START=0
END=500
title=Intro
EOF

rm -f base.mp4
echo "== done =="
ls -la . encrypted fmp4
