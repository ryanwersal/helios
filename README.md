# Helios

A native macOS launcher built with Swift and AppKit.

Helios lives in your menu bar and activates with a global hotkey. Type to search across apps, bookmarks, quick links, and more — results appear instantly as you type.

## Features

- **App launcher** — find and open applications
- **Calculator** — evaluate math expressions inline
- **Date & time** — timezone lookups, time conversions, relative dates, countdowns
- **Firefox bookmarks** — search your bookmarks directly
- **Quick links** — keyword-triggered URL shortcuts (e.g. `gh swift` opens a GitHub search)

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

## License

[GPL-3.0](LICENSE)
