#!/usr/bin/env bash
# Real-asset smoke tests — the release gate.
#
# Runs the just-built ffmpeg/ffprobe against fixtures that exercise every real
# code path in Ghost Downloader. A missing demuxer/parser/bsf/encoder must fail
# HERE so it never reaches a user. Any failure exits non-zero and blocks release.
#
# Usage: smoke-test.sh <bin-dir>
#   <bin-dir> contains ffmpeg(.exe) and ffprobe(.exe).
# Env:
#   EXE_SUFFIX=.exe   for Windows binaries
#   RUNNER="wine64"   to run non-native binaries through an emulator/translator

set -euo pipefail

BIN_DIR="${1:?usage: smoke-test.sh <bin-dir>}"
EXE_SUFFIX="${EXE_SUFFIX:-}"
RUNNER="${RUNNER:-}"
FFMPEG="${BIN_DIR}/ffmpeg${EXE_SUFFIX}"
FFPROBE="${BIN_DIR}/ffprobe${EXE_SUFFIX}"
FIX="$(cd "$(dirname "$0")/../tests/fixtures" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "SMOKE FAIL: $*" >&2; exit 1; }
ok()   { echo "  ok: $*"; }
FF()   { $RUNNER "$FFMPEG" "$@"; }
FP()   { $RUNNER "$FFPROBE" "$@"; }

[ -f "$FFMPEG" ]  || fail "ffmpeg not found at $FFMPEG"
[ -f "$FFPROBE" ] || fail "ffprobe not found at $FFPROBE"

echo "== banner / license =="
FF -hide_banner -version | head -3
# Must be LGPL, never a GPL build.
if FF -hide_banner -version | grep -qi -- "--enable-gpl"; then fail "binary is GPL; expected LGPL"; fi
ok "LGPL build"

echo "== 1. video+audio -> mp4 remux (-c copy): yt-dlp merge / bili / m3u8 mux =="
FF -hide_banner -v error -y -i "$FIX/video.h264.mp4" -i "$FIX/audio.aac.m4a" -c copy "$WORK/merged.mp4" \
  || fail "remux to mp4"
FP -v error "$WORK/merged.mp4" >/dev/null || fail "probe merged.mp4"
ok "remux mp4"

echo "== 2. mpegts (+aac_adtstoasc) -> mp4 =="
FF -hide_banner -v error -y -i "$FIX/segment.ts" -c copy "$WORK/ts.mp4" || fail "mpegts -> mp4"
ok "ts -> mp4"

echo "== 3. AES-128 capability: crypto protocol built in (N_m3u8DL-RE decryption engine) =="
# The app never feeds ffmpeg an .m3u8 — N_m3u8DL-RE parses/decrypts itself and
# uses ffmpeg's crypto protocol. So assert the capability is compiled in rather
# than drive a fragile standalone decrypt.
FF -hide_banner -protocols | grep -qw crypto || fail "crypto protocol missing (HLS AES-128)"
ok "crypto protocol present"

echo "== 4. fmp4 / m4s -> mp4 =="
FF -hide_banner -v error -y -i "$FIX/fmp4/stream.mp4" -c copy "$WORK/fmp4.mp4" || fail "fmp4 remux"
ok "fmp4 remux"

echo "== 5. EAC3 audio track copy =="
FF -hide_banner -v error -y -i "$FIX/audio.eac3.mkv" -c copy "$WORK/eac3.mkv" \
  || fail "eac3 copy (check eac3 demuxer/parser + matroska)"
ok "eac3 copy"

echo "== 6. webp thumbnail -> mp4 mjpeg cover (yt-dlp --embed-thumbnail path) =="
FF -hide_banner -v error -y -i "$WORK/merged.mp4" -i "$FIX/thumb.webp" \
  -map 0 -map 1 -c copy -c:v:1 mjpeg -disposition:v:1 attached_pic "$WORK/cover.mp4" \
  || fail "webp->mp4 thumbnail (check webp/vp8 decoder + mjpeg encoder)"
ok "webp thumbnail embed"

echo "== 7. embed metadata + chapters (ffmetadata, -c copy) =="
FF -hide_banner -v error -y -i "$WORK/merged.mp4" -i "$FIX/meta.ffmeta" -map_metadata 1 -c copy "$WORK/meta.mp4" \
  || fail "ffmetadata embed"
ok "metadata/chapters"

echo "== 8. ffprobe duration (FFmpegStep._probeDuration) =="
DUR="$(FP -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$WORK/merged.mp4")"
[ -n "$DUR" ] || fail "ffprobe duration empty"
ok "ffprobe duration = $DUR"

echo
echo "ALL SMOKE TESTS PASSED"
