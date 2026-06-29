#!/usr/bin/env bash
# Real-asset smoke tests — the release gate.
#
# Runs the just-built ffmpeg/ffprobe against fixtures that exercise every real
# code path in Ghost Downloader. A missing demuxer/parser/bsf/encoder must fail
# HERE so it never reaches a user. Any failure exits non-zero and blocks release.
#
# Usage: smoke-test.sh <bin-dir>
#   <bin-dir> contains ffmpeg(.exe) and ffprobe(.exe). For Android, pass the
#   emulator/adb wrapper dir (see CI). For cross builds that cannot run natively
#   (winarm64 on x64), CI runs this under an emulation layer or skips with a loud
#   warning — never silently.

set -euo pipefail

BIN_DIR="${1:?usage: smoke-test.sh <bin-dir>}"
EXE_SUFFIX="${EXE_SUFFIX:-}"
FFMPEG="${BIN_DIR}/ffmpeg${EXE_SUFFIX}"
FFPROBE="${BIN_DIR}/ffprobe${EXE_SUFFIX}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "SMOKE FAIL: $*" >&2; exit 1; }
ok()   { echo "  ok: $*"; }

[ -x "$FFMPEG" ]  || fail "ffmpeg not executable at $FFMPEG"
[ -x "$FFPROBE" ] || fail "ffprobe not executable at $FFPROBE"

echo "== ffmpeg banner / license =="
"$FFMPEG" -hide_banner -version | head -3
# Must be LGPL, must not be a GPL build.
"$FFMPEG" -hide_banner -version | grep -qi -- "--enable-gpl" && fail "binary is GPL; expected LGPL"
ok "LGPL build"

# Fixtures are generated with the build's own muxers where possible, or shipped
# tiny in tests/fixtures/. Generating a raw source needs an encoder we don't ship,
# so real fixtures (a few KB each) live in the repo. See tests/fixtures/README.md.
FIX="$(cd "$(dirname "$0")/../tests/fixtures" && pwd)"

echo "== 1. video+audio -> mp4 remux (-c copy): yt-dlp merger / bili / m3u8 mux =="
"$FFMPEG" -hide_banner -v error -y \
  -i "$FIX/video.h264.mp4" -i "$FIX/audio.aac.m4a" \
  -c copy "$WORK/merged.mp4" || fail "remux to mp4"
"$FFPROBE" -v error "$WORK/merged.mp4" >/dev/null || fail "probe merged.mp4"
ok "remux mp4"

echo "== 2. mpegts (+aac_adtstoasc) -> mp4: HLS/TS segment mux =="
"$FFMPEG" -hide_banner -v error -y -i "$FIX/segment.ts" -c copy "$WORK/ts.mp4" \
  || fail "mpegts -> mp4"
ok "ts -> mp4"

echo "== 3. HLS AES-128 decrypt + mux: m3u8_pack decryption engine =="
# fixture: a local m3u8 with #EXT-X-KEY METHOD=AES-128 pointing at a local key + ts.
"$FFMPEG" -hide_banner -v error -y -allowed_extensions ALL \
  -i "$FIX/encrypted/index.m3u8" -c copy "$WORK/dec.mp4" \
  || fail "HLS AES-128 decrypt+mux (check crypto protocol + hls demuxer)"
ok "AES-128 decrypt"

echo "== 4. fmp4 / m4s init+media -> mp4 =="
"$FFMPEG" -hide_banner -v error -y -i "$FIX/fmp4/stream.mp4" -c copy "$WORK/fmp4.mp4" \
  || fail "fmp4 remux"
ok "fmp4 remux"

echo "== 5. EAC3 audio track copy =="
"$FFMPEG" -hide_banner -v error -y -i "$FIX/audio.eac3.mkv" -c copy "$WORK/eac3.mkv" \
  || fail "eac3 copy (check eac3 demuxer/parser + matroska)"
ok "eac3 copy"

echo "== 6. webp thumbnail -> mp4 cover (yt-dlp --embed-thumbnail, the only encode) =="
"$FFMPEG" -hide_banner -v error -y \
  -i "$WORK/merged.mp4" -i "$FIX/thumb.webp" \
  -map 0 -map 1 -c copy -c:v:1 png -disposition:v:1 attached_pic \
  "$WORK/withcover.mp4" || fail "webp->mp4 thumbnail (check webp/vp8 decoder + png encoder)"
ok "webp thumbnail embed"

echo "== 7. embed metadata + chapters (ffmetadata, -c copy) =="
"$FFMPEG" -hide_banner -v error -y -i "$WORK/merged.mp4" -i "$FIX/meta.ffmeta" \
  -map_metadata 1 -c copy "$WORK/meta.mp4" || fail "ffmetadata embed"
ok "metadata/chapters"

echo "== 8. ffprobe duration (FFmpegStep._probeDuration) =="
DUR="$("$FFPROBE" -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 "$WORK/merged.mp4")"
[ -n "$DUR" ] || fail "ffprobe duration empty"
ok "ffprobe duration = $DUR"

echo
echo "ALL SMOKE TESTS PASSED"
