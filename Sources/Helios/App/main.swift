import AppKit

// Run against the assembled app in CI, where SwiftPM's development paths
// cannot hide missing resources or an incompatible bundle lookup.
if CommandLine.arguments.contains("--check-resources") {
    let valid = MainActor.assumeIsolated {
        BrandImages.appIcon?.isValid == true
            && BrandImages.menuBarIcon.representations.count == 2
            && BrandImages.menuBarIcon.isTemplate
    }
    guard valid else {
        fputs("Helios branding resources are missing or invalid\n", stderr)
        exit(1)
    }
    print("Helios app and menu bar resources loaded successfully")
    exit(0)
}

let app = NSApplication.shared

// Run as accessory (no dock icon)
app.setActivationPolicy(.accessory)

/// main.swift always runs on the main thread
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate

app.run()
