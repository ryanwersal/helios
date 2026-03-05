import Foundation
@testable import Helios
import Testing

struct FirefoxProfileLocatorTests {
    private let supportDir = URL(fileURLWithPath: "/fake/Firefox")

    // MARK: - Install section handling (modern Firefox)

    @Test("Install section Default is preferred over Profile section Default=1")
    func installSectionPreferred() {
        let ini = """
        [Profile0]
        Name=default
        IsRelative=1
        Path=Profiles/old.default
        Default=1

        [Install2656FF1E876E9973]
        Default=Profiles/new.default-release
        """
        let result = FirefoxProfileLocator.parseDefaultProfile(from: ini, supportDir: supportDir)
        #expect(result == supportDir.appendingPathComponent("Profiles/new.default-release"))
    }

    @Test("Install section path resolved relative to supportDir")
    func installSectionRelativePath() {
        let ini = """
        [InstallABCDEF123456]
        Default=Profiles/abc123.default-release
        """
        let result = FirefoxProfileLocator.parseDefaultProfile(from: ini, supportDir: supportDir)
        #expect(result == supportDir.appendingPathComponent("Profiles/abc123.default-release"))
    }

    @Test("Multiple Install sections — uses first")
    func multipleInstallSectionsUsesFirst() {
        let ini = """
        [Install1111111111111111]
        Default=Profiles/first.default

        [Install2222222222222222]
        Default=Profiles/second.default
        """
        let result = FirefoxProfileLocator.parseDefaultProfile(from: ini, supportDir: supportDir)
        #expect(result == supportDir.appendingPathComponent("Profiles/first.default"))
    }

    @Test("Install section with other keys correctly extracts Default")
    func installSectionExtractsDefault() {
        let ini = """
        [Install2656FF1E876E9973]
        Default=Profiles/abc.default-release
        Locked=1
        """
        let result = FirefoxProfileLocator.parseDefaultProfile(from: ini, supportDir: supportDir)
        #expect(result == supportDir.appendingPathComponent("Profiles/abc.default-release"))
    }

    // MARK: - Profile section handling (legacy Firefox)

    @Test("Profile section with Default=1 returns its Path")
    func profileSectionDefault() {
        let ini = """
        [Profile0]
        Name=default
        IsRelative=1
        Path=Profiles/xyz.default
        Default=1
        """
        let result = FirefoxProfileLocator.parseDefaultProfile(from: ini, supportDir: supportDir)
        #expect(result == supportDir.appendingPathComponent("Profiles/xyz.default"))
    }

    @Test("Relative path with IsRelative=1")
    func relativePath() {
        let ini = """
        [Profile0]
        Path=Profiles/rel.default
        IsRelative=1
        Default=1
        """
        let result = FirefoxProfileLocator.parseDefaultProfile(from: ini, supportDir: supportDir)
        #expect(result == supportDir.appendingPathComponent("Profiles/rel.default"))
    }

    @Test("Absolute path with IsRelative=0")
    func absolutePath() {
        let ini = """
        [Profile0]
        Path=/absolute/path/to/profile
        IsRelative=0
        Default=1
        """
        let result = FirefoxProfileLocator.parseDefaultProfile(from: ini, supportDir: supportDir)
        #expect(result == URL(fileURLWithPath: "/absolute/path/to/profile"))
    }

    @Test("Multiple profiles, only one with Default=1")
    func multipleProfilesOneDefault() {
        let ini = """
        [Profile0]
        Name=other
        IsRelative=1
        Path=Profiles/other.profile

        [Profile1]
        Name=default
        IsRelative=1
        Path=Profiles/the-default.profile
        Default=1

        [Profile2]
        Name=work
        IsRelative=1
        Path=Profiles/work.profile
        """
        let result = FirefoxProfileLocator.parseDefaultProfile(from: ini, supportDir: supportDir)
        #expect(result == supportDir.appendingPathComponent("Profiles/the-default.profile"))
    }

    @Test("Default=1 in last section with no subsequent section header")
    func defaultInLastSection() {
        let ini = """
        [Profile0]
        Name=other
        IsRelative=1
        Path=Profiles/other.profile

        [Profile1]
        Name=default
        IsRelative=1
        Path=Profiles/last.default
        Default=1
        """
        let result = FirefoxProfileLocator.parseDefaultProfile(from: ini, supportDir: supportDir)
        #expect(result == supportDir.appendingPathComponent("Profiles/last.default"))
    }

    @Test("First Default=1 profile wins when multiple exist")
    func firstDefaultWins() {
        let ini = """
        [Profile0]
        Name=first
        IsRelative=1
        Path=Profiles/first.default
        Default=1

        [Profile1]
        Name=second
        IsRelative=1
        Path=Profiles/second.default
        Default=1
        """
        let result = FirefoxProfileLocator.parseDefaultProfile(from: ini, supportDir: supportDir)
        #expect(result == supportDir.appendingPathComponent("Profiles/first.default"))
    }

    // MARK: - Edge cases

    @Test("Empty string returns nil")
    func emptyStringReturnsNil() {
        let result = FirefoxProfileLocator.parseDefaultProfile(from: "", supportDir: supportDir)
        #expect(result == nil)
    }

    @Test("No Install or Profile defaults returns nil")
    func noDefaultsReturnsNil() {
        let ini = """
        [General]
        StartWithLastProfile=1
        Version=2

        [Profile0]
        Name=default
        IsRelative=1
        Path=Profiles/abc.default
        """
        let result = FirefoxProfileLocator.parseDefaultProfile(from: ini, supportDir: supportDir)
        #expect(result == nil)
    }

    @Test("Profile with Default=1 but no Path returns nil")
    func defaultWithoutPathReturnsNil() {
        let ini = """
        [Profile0]
        Name=default
        IsRelative=1
        Default=1
        """
        let result = FirefoxProfileLocator.parseDefaultProfile(from: ini, supportDir: supportDir)
        #expect(result == nil)
    }

    @Test("Section with Path but no Default=1 is skipped")
    func pathWithoutDefaultSkipped() {
        let ini = """
        [Profile0]
        Name=default
        IsRelative=1
        Path=Profiles/abc.default
        """
        let result = FirefoxProfileLocator.parseDefaultProfile(from: ini, supportDir: supportDir)
        #expect(result == nil)
    }

    @Test("Leading and trailing whitespace in lines is handled")
    func whitespaceHandled() {
        let ini = """
          [Profile0]
          Path=Profiles/ws.default
          IsRelative=1
          Default=1
        """
        let result = FirefoxProfileLocator.parseDefaultProfile(from: ini, supportDir: supportDir)
        #expect(result == supportDir.appendingPathComponent("Profiles/ws.default"))
    }

    @Test("Real-world profiles.ini from this machine")
    func realWorldProfilesIni() {
        let ini = """
        [Profile1]
        Name=default
        IsRelative=1
        Path=Profiles/1cyimoqd.default
        Default=1

        [Profile0]
        Name=default-release
        IsRelative=1
        Path=Profiles/4ko7ac3j.default-release

        [General]
        StartWithLastProfile=1
        Version=2

        [Install2656FF1E876E9973]
        Default=Profiles/4ko7ac3j.default-release
        Locked=1
        """
        let result = FirefoxProfileLocator.parseDefaultProfile(from: ini, supportDir: supportDir)
        // Install section is preferred over Profile section
        #expect(result == supportDir.appendingPathComponent("Profiles/4ko7ac3j.default-release"))
    }
}
