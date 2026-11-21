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

// Exercise the exact production provider and result presentation from an assembled app.
if let smokeIndex = CommandLine.arguments.firstIndex(of: "--smoke-time-conversion") {
    let queryIndex = CommandLine.arguments.index(after: smokeIndex)
    guard queryIndex < CommandLine.arguments.endIndex else {
        fputs("Usage: Helios --smoke-time-conversion \"<query>\"\n", stderr)
        exit(64)
    }
    let results = MainActor.assumeIsolated {
        DateTimeProvider().results(for: CommandLine.arguments[queryIndex])
    }
    guard !results.isEmpty else {
        fputs("No date/time result\n", stderr)
        exit(2)
    }
    var hasDiagnostic = false
    for result in results {
        print("TITLE: \(result.title)")
        print("SUBTITLE: \(result.subtitle)")
        switch result.action {
        case let .copyToClipboard(value):
            print("COPY: \(value)")
        case .none:
            hasDiagnostic = true
            print("ACTION: none")
        case .openURL:
            fputs("Unexpected URL action in date/time result\n", stderr)
            exit(3)
        }
    }
    exit(hasDiagnostic ? 2 : 0)
}

let app = NSApplication.shared

// Run as accessory (no dock icon)
app.setActivationPolicy(.accessory)

/// main.swift always runs on the main thread
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate

app.run()
