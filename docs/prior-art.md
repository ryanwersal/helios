# Prior Art: macOS Launchers

A survey of existing macOS launchers — their strengths, architectures, and relevance to Helios.

---

## Raycast

**Tech:** Swift + AppKit | Extensions: TypeScript/React in Node.js workers
**Pricing:** Free (generous), Pro $8-10/mo | https://www.raycast.com/

**Strengths:**
- Extraordinary free tier: clipboard history, window management (70+ layouts), snippets, calculator, emoji picker, 1,500+ extensions.
- Extension ecosystem with standardized React/TypeScript API. Extensions run in isolated Node.js workers — crash-safe.
- AI integration woven into OS-level workflow: highlight text anywhere, invoke AI for summarization/translation/rewriting.
- Replaces 5-6 standalone apps (clipboard manager, window manager, text expander, notes, Pomodoro timer).
- Native Swift/AppKit core with sub-100ms response times.
- Action Panel: every result has contextual actions with keyboard shortcut hints.
- Backed by $48M in funding (Accel, Coatue, Atomico).

**Weaknesses:** Closed source core. No Linux. Extension security relies on community review, not sandboxing. Vendor lock-in risk. AI pricing is confusing (three separate tiers).

---

## Alfred

**Tech:** Objective-C + Cocoa/AppKit
**Pricing:** Free (basic), Powerpack $43, Mega Supporter $75 (lifetime) | https://www.alfredapp.com/

**Strengths:**
- The fastest launcher. Noticeably faster than Raycast and significantly faster than Spotlight in benchmarks and user perception.
- Adaptive learning — ranks results by personal usage frequency, locally, no cloud.
- Visual node-graph workflow system supporting bash, zsh, Python, Ruby, PHP, Perl, AppleScript, JXA.
- Privacy-first and offline-first. No accounts, no telemetry, no cloud dependency.
- Modifier-key action system — Cmd/Option/Ctrl on a selected result triggers different actions without navigating submenus.
- Universal Actions — select text/files anywhere, press a hotkey, get contextual actions system-wide.
- One-time purchase with lifetime upgrade option.
- File search widely regarded as faster and more accurate than Spotlight and Raycast.

**Weaknesses:** UI feels dated ("from a past era of Mac apps, circa 2010"). Clipboard/snippets/workflows require paid Powerpack. No window management. No AI. Development pace has slowed. Relies on macOS Spotlight index (MDQuery), not its own.

---

## Monarch

**Tech:** Rust (core engine), native macOS
**Pricing:** $20-30 one-time | https://www.monarchlauncher.com/

**Strengths:**
- Exceptional performance: ~0.3s startup, <1% CPU standby, ~80MB memory. Results 150x faster than Spotlight.
- Clean, dark-first aesthetic: floating panel, large rounded corners, oversized search typography, bottom context bar, no window chrome. Tab-cycling between modes.
- Clipboard history with filtering by app/domain, encryption, renameable items, pause/resume, no storage limits.
- Calculator with named variables (save `rent = 2400`, reference later). Date math, timezone, unit/currency conversion.
- Markdown notes captured from anywhere (even fullscreen) via hotkey. Stored as local .md files, Obsidian-compatible.
- Superlinks: parameterized URL shortcuts with variables, defaults, optional params. Combines bookmarks + shortcuts + tab switching.
- Matchlinks: focus existing browser tab if URL matches instead of opening a duplicate.
- Four keyboard shortcut types: Combo, Akimbo (dual modifier), Chord (two-step), Double-Tap. Ambidextrous mode.
- Zero configuration. One-time purchase. Full theming on all license tiers.

**Weaknesses:** No frequency-based app ordering (alphabetical only). Animations can feel janky. No AI. Superlinks not supported in Firefox/Arc. Smaller community. Some reviewers consider it "alpha-feeling."

---

## LaunchBar

**Tech:** Native Cocoa/AppKit (Objective-C)
**Pricing:** $29 single, $49 family | https://www.obdev.at/products/launchbar

**Strengths:**
- 20+ years of native Cocoa optimization. Originated on NeXTSTEP (2001).
- Abbreviation-based adaptive search — type "itun" for iTunes, learns your shortcuts over time.
- Instant Send: select text/files anywhere, invoke LaunchBar, immediately act on selection.
- Custom actions in AppleScript, JXA, Ruby, Python, PHP, shell.
- Deep macOS integration: Finder Tags, Shortcuts, Reminders, Safari Reading List, iCloud Tabs.
- Extremely lightweight. One-time purchase.

**Weaknesses:** UI feels dated. Smaller community. Declining mindshare. No true free tier (nag-ware). Documentation could be better.

---

## Quicksilver

**Tech:** Objective-C + Cocoa/AppKit, open source (Apache 2.0)
**Pricing:** Free | https://qsapp.com/

**Strengths:**
- The original (2003). Invented the keyboard launcher paradigm that every successor builds upon.
- Noun-verb-argument model: three-pane interface for composable commands. Uniquely expressive.
- Proxy objects (e.g., "current selection" as a dynamic noun) enable contextual workflows.
- Completely free, no limitations. Still actively maintained (v2.5.6, Feb 2026). Native Apple Silicon.
- Plugin architecture with installable modules.
- Adaptive learning.

**Weaknesses:** Aging Objective-C codebase from 2003. Volunteer-maintained. Steep learning curve. Declining plugin ecosystem. Sparse documentation. UI not modernized.

---

## Sol

**Tech:** React Native for macOS, TypeScript/Swift
**Pricing:** Free (MIT License) | https://github.com/ospfranco/sol

**Strengths:**
- Free and open source with a broad built-in feature set (~95% of what most users need).
- App launching, clipboard manager, window manager, emoji picker, calculator, Google Translate/Maps, calendar, developer tools (UUID gen, JSON formatting).
- Scripting via AppleScript, JXA, Swift plugin templates.
- Active development with responsive maintainer.

**Weaknesses:** React Native layer adds overhead vs pure-native. Smaller community. Fewer extensions. Less mature than established alternatives.

---

## Spotlight (macOS built-in)

**Tech:** Native system component (Obj-C/C++), mds daemon
**Pricing:** Free (included with macOS)

**Strengths:**
- Zero setup. Always available, deeply OS-integrated. No resource overhead.
- Full filesystem indexing via metadata server.
- Natural language queries ("photos from last week").
- macOS 26 Tahoe: hundreds of executable actions, Shortcuts integration, clipboard manager, third-party cloud document search.
- Core Spotlight API for third-party app integration.

**Weaknesses:** Indexing frequently breaks after OS upgrades. No customization, scripting, or extension ecosystem. Inconsistent result ranking. No abbreviation matching.

---

## Key Patterns Worth Adopting

| Pattern | Source | Notes |
|---------|--------|-------|
| Adaptive ranking by usage frequency | Alfred, Quicksilver, LaunchBar | Learn which results the user picks for which queries |
| Modifier-key action variants | Alfred | Cmd/Option/Ctrl on a result = different actions, zero extra keystrokes |
| Tab-cycling between modes | Monarch | Clean UX for multiple tool modes in one panel |
| Calculator with named variables | Monarch | Small lift on top of existing Expression library |
| Bottom context bar with shortcut hints | Monarch | Already implemented in Helios |
| Abbreviation matching (initials) | LaunchBar, Monarch | "gc" -> Google Chrome, "vsc" -> VS Code |
| Pre-rendered icons | Raycast, Helios | Already implemented — eliminates pop-in |
| Noun-verb composability | Quicksilver | Future consideration for advanced actions |
| Clipboard history | Monarch, Raycast, Alfred | High-value future addition |
| System commands provider | Monarch, Raycast | Low-effort provider (volume, sleep, lock, Wi-Fi toggle) |
