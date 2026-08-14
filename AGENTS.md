# AGENTS.md

## Cursor Cloud specific instructions

### What Replay is

Replay is a **macOS-only SwiftUI/AppKit desktop app** built with Swift Package Manager
(`Package.swift`, `platforms: [.macOS(.v13)]`, single executable target `Replay`).
There is no client/server split, no database, and no ports. See `README.md` and
`CONTRIBUTING.md` for the canonical build/run/test commands.

### Platform boundary (important)

The Cursor Cloud VM is **Linux x86_64**, but Replay is macOS-only. As a result:

- The full app **cannot build or run on Linux**. Sources import `AppKit`, `SwiftUI`,
  `AVKit`, and `MediaPlayer`, so `swift build -c release --product Replay` fails with
  `no such module 'AppKit'`. Building and running the GUI app requires macOS 13+.
- The full test suite `./scripts/test.sh` **cannot fully run on Linux** either. 4 of its
  8 checks depend on macOS-only APIs/frameworks and do not compile here:
  `url_intake` (`NSDataDetector`), `power_mode` (`ProcessInfo.isLowPowerModeEnabled`),
  `playback_command` (`AVKit`), `activation_click` (`AppKit`).
- Full build + test is exercised by CI on `macos-26` runners
  (`.github/workflows/ci.yml`). Do that on macOS, not on this VM.
- Runtime tools `yt-dlp` / `ffmpeg` / `deno` matter only to the real macOS app at
  runtime; they are irrelevant on this Linux VM.

### What you CAN do on this Linux VM

An open-source Swift toolchain (installed via `swiftly`, currently 6.3.x) is available.
`swift`/`swiftc` live in `~/.local/share/swiftly/bin`. A **non-login shell may not have
them on PATH**, so source the env first:

```sh
. "$HOME/.local/share/swiftly/env.sh"
```

You can compile and run the 4 Foundation-only core-logic checks (a subset of
`scripts/test.sh`). From the repo root:

```sh
. "$HOME/.local/share/swiftly/env.sh"
swiftc Sources/Replay/DownloadRetryPolicy.swift tools/retry_policy_check.swift -o /tmp/c && /tmp/c
swiftc Sources/Replay/WatchItem.swift Sources/Replay/ChapterMetadata.swift tools/resume_model_check.swift -o /tmp/c && /tmp/c
swiftc Sources/Replay/VideoSubtitles.swift tools/subtitle_parser_check.swift -o /tmp/c && /tmp/c
swiftc Sources/Replay/ReplayMigration.swift tools/replay_migration_check.swift -o /tmp/c && /tmp/c
```

These cover download retry policy, resume model, subtitle parsing (including the
YouTube rolling-subtitle dedup logic), and queue-data migration.

### Notes

- `Package.swift` declares **no external Swift package dependencies**, so there is
  nothing to resolve/fetch per build.
- The Swift toolchain needs a few system libraries (`libcurl4-openssl-dev`,
  `libpython3-dev`, `libxml2-dev`, `libncurses-dev`, `libz3-dev`, `gnupg2`). If a
  Foundation compile fails on a fresh VM with a linker/module error, install them with
  `sudo apt-get install -y ...`.
- There is **no lint tooling** configured (no SwiftLint/SwiftFormat, no lint CI step).
