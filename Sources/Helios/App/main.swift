import AppKit

let app = NSApplication.shared

// Run as accessory (no dock icon)
app.setActivationPolicy(.accessory)

/// main.swift always runs on the main thread
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate

app.run()
