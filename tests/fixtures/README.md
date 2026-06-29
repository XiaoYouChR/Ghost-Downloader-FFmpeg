# Smoke-test fixtures

Tiny real media (a few KB each) that exercise every Ghost Downloader FFmpeg path.
A minimal build ships no source encoders, so fixtures are committed here rather
than generated at test time.

Required files (referenced by `scripts/smoke-test.sh`):

| File | Exercises |
|---|---|
| `video.h264.mp4` | H.264 video-only, for `-c copy` merge |
| `audio.aac.m4a` | AAC audio-only, merge partner |
| `segment.ts` | MPEG-TS segment → mp4 (aac_adtstoasc, h264_mp4toannexb) |
| `encrypted/index.m3u8` + `encrypted/key.bin` + `encrypted/seg0.ts` | HLS `#EXT-X-KEY METHOD=AES-128` decrypt + mux (crypto protocol) |
| `fmp4/stream.mp4` | fragmented mp4 / m4s init+media |
| `audio.eac3.mkv` | E-AC-3 track copy (eac3 demuxer/parser) |
| `thumb.webp` | webp → mp4 cover (webp/vp8 decoder + png encoder) |
| `meta.ffmeta` | `--embed-metadata` / `--embed-chapters` (ffmetadata demuxer) |

## How to generate (once, with a full ffmpeg, then commit the outputs)

```bash
# from a sine + testsrc, kept ~0.5s so files stay tiny
ffmpeg -f lavfi -i testsrc=d=0.5:s=128x96 -c:v libx264 -an video.h264.mp4
ffmpeg -f lavfi -i sine=d=0.5 -c:a aac audio.aac.m4a
ffmpeg -i video.h264.mp4 -i audio.aac.m4a -c copy -f mpegts segment.ts
# ... see commit history for the exact commands used to produce each fixture.
```

Keep fixtures minimal; they are test inputs, not sample content.
