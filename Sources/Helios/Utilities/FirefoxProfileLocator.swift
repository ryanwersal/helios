import Foundation

struct FirefoxProfileLocator {
    static let firefoxSupportDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Firefox")

    /// Locate the default Firefox profile directory by parsing profiles.ini.
    static func defaultProfilePath() -> URL? {
        let profilesIni = firefoxSupportDir.appendingPathComponent("profiles.ini")
        guard let contents = try? String(contentsOf: profilesIni, encoding: .utf8) else {
            return nil
        }

        var currentPath: String?
        var currentIsRelative = true
        var foundDefault = false

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("[") {
                // New section — if we had a default, return it
                if foundDefault, let path = currentPath {
                    return resolvedProfileURL(path: path, isRelative: currentIsRelative)
                }
                currentPath = nil
                currentIsRelative = true
                foundDefault = false
            } else if trimmed.hasPrefix("Path=") {
                currentPath = String(trimmed.dropFirst("Path=".count))
            } else if trimmed.hasPrefix("IsRelative=") {
                currentIsRelative = String(trimmed.dropFirst("IsRelative=".count)) == "1"
            } else if trimmed == "Default=1" {
                foundDefault = true
            }
        }

        // Check last section
        if foundDefault, let path = currentPath {
            return resolvedProfileURL(path: path, isRelative: currentIsRelative)
        }

        // Fallback: look for any profile directory
        return fallbackProfilePath()
    }

    /// Find the places.sqlite file within the profile directory.
    static func placesDatabase() -> URL? {
        guard let profile = defaultProfilePath() else { return nil }
        let places = profile.appendingPathComponent("places.sqlite")
        return FileManager.default.fileExists(atPath: places.path) ? places : nil
    }

    private static func resolvedProfileURL(path: String, isRelative: Bool) -> URL {
        if isRelative {
            return firefoxSupportDir.appendingPathComponent(path)
        } else {
            return URL(fileURLWithPath: path)
        }
    }

    private static func fallbackProfilePath() -> URL? {
        let profilesDir = firefoxSupportDir.appendingPathComponent("Profiles")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: profilesDir, includingPropertiesForKeys: nil
        ) else {
            return nil
        }
        // Look for a directory ending in .default-release or .default
        return entries.first { $0.lastPathComponent.hasSuffix(".default-release") }
            ?? entries.first { $0.lastPathComponent.hasSuffix(".default") }
            ?? entries.first
    }
}
