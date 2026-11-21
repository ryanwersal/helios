# Helios

<img src="docs/branding/AppIcon.png" alt="Helios solar spiral icon" width="128" />

A native macOS launcher built with Swift and AppKit.

Helios lives in your menu bar and activates with a global hotkey. Type to search across apps, bookmarks, quick links, and more — results appear instantly as you type.

## Features

- **App launcher** — find and open applications
- **Calculator** — evaluate math expressions inline
- **Date & time** — timezone lookups, time conversions, relative dates, countdowns
- **Firefox bookmarks** — search your bookmarks directly
- **Quick links** — keyword-triggered URL shortcuts (e.g. `gh swift` opens a GitHub search)

### Time conversions

Use ordinary phrases with either a 12-hour or 24-hour clock:

```text
3pm in New York to London
convert 15:30 from Berlin to Tokyo
3pm est in pst
```

Add an ISO calendar date when rollover or daylight-saving behavior needs to be
reproducible. Helios shows the destination date when the conversion crosses a
day boundary:

```text
2026-01-15 11:30pm from America/Los_Angeles to Asia/Tokyo
```

Common city aliases such as `New York`, `NYC`, and `Tokyo` work alongside raw
IANA identifiers such as `America/New_York`. Globally ambiguous abbreviations
such as `CST` and `IST` produce guidance instead of choosing a region silently;
use a city or IANA identifier to disambiguate them.

Local times skipped by a spring-forward transition are rejected with a valid
correction. If a fall-back transition repeats a local time, Helios returns both
possibilities, labeled with their timezone abbreviation and UTC offset.

## Install

### Homebrew

```sh
brew install --cask ryanwersal/tools/helios
```

### From source

Requires Swift 6.2+ and macOS 15+.

```sh
swift build
swift run
```

## Development

```sh
swift build          # build the project
swift test           # run tests
swiftlint            # lint
swiftformat .        # format
```

The app and menu bar share a solar spiral mark. Generated source artwork lives in
`docs/branding`; the built-in image generation prompts are recorded in
`docs/branding/prompts.txt`. Run `bash scripts/generate-icons.sh` on macOS to rebuild
the multi-resolution app icon and the 1×/2× template glyphs.

## License

[Apache-2.0](LICENSE)
