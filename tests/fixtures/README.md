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

## How to regenerate

Run the generator with a full ffmpeg (needs libx264, aac, eac3, libwebp):

```bash
bash scripts/make-fixtures.sh            # fully synthetic (testsrc2 + sine)
bash scripts/make-fixtures.sh clip.mp4   # use clip.mp4's video stream, synthetic audio
```

Everything is cut to ~0.5s at <=160px, so each file is a few KB. Audio is
always a synthetic sine (so no real audio source is needed).

Provenance: the committed fixtures' video frames come from a short, low-res
(160px / 0.5s) snippet of a user-provided clip; audio is synthetic. Swap to the
fully synthetic form above if you prefer no real frames. They are test inputs,
not sample content.
