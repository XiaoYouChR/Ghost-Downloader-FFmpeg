# Ghost-Downloader-FFmpeg

Minimal, LGPL, self-built FFmpeg for [Ghost Downloader](https://github.com/XiaoYouChR/Ghost-Downloader-3).

Ghost Downloader only stream-copies, muxes, decrypts AES-128, reads duration, and
converts a webp thumbnail for mp4 — it **never transcodes**. A full GPL build
(~80 MB) is almost entirely dead weight. This repo builds exactly what the app
uses (~4–6 MB/platform) and publishes it to GitHub Releases for the app's
one-click install to fetch.

See the design rationale in the app's `docs/adr/0002-minimal-lgpl-self-built-ffmpeg.md`.

## What it builds

| Target | Asset (version-less) | Notes |
|---|---|---|
| Windows x64 | `ffmpeg-win64.zip` | cross from Linux (BtbN toolchain) |
| Windows arm64 | `ffmpeg-winarm64.zip` | cross; smoke test needs emulation |
| Linux x64 | `ffmpeg-linux-x64.tar.gz` | |
| Linux arm64 | `ffmpeg-linux-arm64.tar.gz` | cross |
| macOS x64 | `ffmpeg-macos-x64.tar.gz` | native runner; unsigned |
| macOS arm64 | `ffmpeg-macos-arm64.tar.gz` | native runner; unsigned |
| Android arm64 | `ffmpeg-android-arm64.tar.gz` | NDK r28, minSdk 28, no MediaCodec |

Each asset ships `ffmpeg`(`.exe`) + `ffprobe`(`.exe`) and a `<asset>.sha256`
sidecar the app verifies after download.

## Layout

```
scripts/configure-flags.sh      # SINGLE SOURCE OF TRUTH for the feature whitelist
scripts/build-windows-linux.sh  # win64/winarm64/linux-x64/linux-arm64 (BtbN toolchain)
scripts/build-macos.sh          # native macOS, one arch per run
scripts/build-android.sh        # NDK arm64
scripts/smoke-test.sh           # release gate: real-asset tests, fail = no release
scripts/package.sh              # archive + .sha256, deterministic asset names
tests/fixtures/                 # tiny media exercising every app code path
.github/workflows/build.yml     # matrix build + smoke + release on tag
```

## Versioning

Pin upstream FFmpeg stable (`n8.1.1`, matching the app's Android baseline). Tag
this repo `n8.1.1-gd1`, `n8.1.1-gd2`, … The app fetches **this repo's**
`/releases/latest`, so an FFmpeg security bump ships without an app update.

## Status — skeleton

This is a scaffold. The feature whitelist, smoke tests, packaging, and CI shape
are concrete; the cross-toolchain wiring in `build-windows-linux.sh` and the
Android emulator smoke step are marked **TODO** and unverified. Nothing is proven
until `smoke-test.sh` passes green in CI for a target.

## How the app consumes it

`FFmpegRuntime.installTask()` builds `…/releases/latest/download/ffmpeg-<target>.<ext>`,
routes both the release API call and the download URL through
`github_pack.toProxiedUrl()` (CN mirror → GitHub), then verifies the `.sha256`.
On macOS the install step clears `com.apple.quarantine` so the spawned binary
isn't blocked by Gatekeeper.
