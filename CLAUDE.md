# Helios - Development Guide

## Project
Native macOS launcher (Swift + AppKit). See `PLAN.md` for full architecture and implementation plan.

## Build & Test

All common tasks are defined as mise tasks. Use these instead of raw commands:

```
mise run check         # Format + lint + build (run after every code change)
mise run format        # Auto-format Swift files
mise run format-check  # Check formatting without modifying files
mise run lint          # Lint Swift files (--strict)
mise run build-check   # Debug build with warnings-as-errors
mise run build         # Build release .app bundle
swift test             # Run tests
```

**After completing any code changes**, always run `mise run check` and fix any issues before presenting work as done. This auto-formats and lints — it's fast and catches most CI failures early.

## Key Conventions
- **Pure AppKit** — no SwiftUI, no storyboards, no XIBs. All UI is programmatic.
- **Swift 6 concurrency** — `@MainActor` on all UI types, actors for shared mutable state, no `DispatchQueue.main.async` in new code.
- **Provider pattern** — search domains are `SearchProvider` protocol implementations. Router dispatches to providers.
- **Value types for data** — structs for models (`SearchResult`, etc.), classes only for AppKit subclasses and shared state.
- **Dependency injection** — providers injected via initializer for testability.
- **System colors only** — no hardcoded colors. Use `NSColor.textColor`, `.windowBackgroundColor`, etc. for dark mode support.

## Code Review

After completing a sizeable unit of work (finishing an implementation phase, adding a new provider, building a major UI component, or any change touching 3+ files), you MUST spawn the `audit` subagent before moving on. This is a project-specific subagent defined in `.claude/agents/audit.md` that reviews for Swift language quality, concurrency correctness, AppKit best practices, memory safety, architecture adherence, performance, accessibility, and macOS platform conventions. Fix any critical issues and improvements it raises before continuing work.
