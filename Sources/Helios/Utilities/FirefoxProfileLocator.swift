import Foundation

struct FirefoxProfileLocator {
    static let firefoxSupportDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Firefox")

    /// Locate the default Firefox profile directory by parsing profiles.ini.
    ///
    /// Modern Firefox uses `[Install...]` sections with a `Default=` path to
    /// identify the active profile. Older installs rely on `Default=1` in
    /// `[Profile...]` sections. We check both, preferring the Install path.
    static func defaultProfilePath() -> URL? {
        let profilesIni = firefoxSupportDir.appendingPathComponent("profiles.ini")
        guard let contents = try? String(contentsOf: profilesIni, encoding: .utf8) else {
            return nil
        }
        return parseDefaultProfile(from: contents, supportDir: firefoxSupportDir)
            ?? fallbackProfilePath()
    }

    /// Parses Firefox profiles.ini content and returns the URL of the default
    /// profile directory, resolved against the given support directory.
    internal static func parseDefaultProfile(from contents: String, supportDir: URL) -> URL? {
        var installDefault: String?
        var profileDefault: URL?

        var currentPath: String?
        var currentIsRelative = true
        var foundDefault = false
        var inInstallSection = false

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("[") {
                // Finalize previous section
                if !inInstallSection, foundDefault, let path = currentPath, profileDefault == nil {
                    profileDefault = resolvedProfileURL(
                        path: path, isRelative: currentIsRelative, supportDir: supportDir
                    )
                }
                inInstallSection = trimmed.hasPrefix("[Install")
                currentPath = nil
                currentIsRelative = true
                foundDefault = false
            } else if inInstallSection, trimmed.hasPrefix("Default="), installDefault == nil {
                installDefault = String(trimmed.dropFirst("Default=".count))
            } else if trimmed.hasPrefix("Path=") {
                currentPath = String(trimmed.dropFirst("Path=".count))
            } else if trimmed.hasPrefix("IsRelative=") {
                currentIsRelative = String(trimmed.dropFirst("IsRelative=".count)) == "1"
            } else if trimmed == "Default=1" {
                foundDefault = true
            }
        }

        // Finalize last section
        if !inInstallSection, foundDefault, let path = currentPath, profileDefault == nil {
            profileDefault = resolvedProfileURL(
                path: path, isRelative: currentIsRelative, supportDir: supportDir
            )
        }

        // Prefer Install section default (modern Firefox), fall back to Profile section default.
        // Install sections always use relative paths (no IsRelative key).
        if let installPath = installDefault {
            return supportDir.appendingPathComponent(installPath)
        }
        return profileDefault
    }

    /// Find the places.sqlite file within the profile directory.
    static func placesDatabase() -> URL? {
        guard let profile = defaultProfilePath() else { return nil }
        let places = profile.appendingPathComponent("places.sqlite")
        return FileManager.default.fileExists(atPath: places.path) ? places : nil
    }

    private static func resolvedProfileURL(path: String, isRelative: Bool, supportDir: URL) -> URL {
        if isRelative {
            return supportDir.appendingPathComponent(path)
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
