import AppKit

@MainActor
enum BrandImages {
    static let appIcon: NSImage? = url("AppIcon", extension: "icns").flatMap(NSImage.init(contentsOf:))

    static let menuBarIcon: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        for name in ["MenuBarTemplate", "MenuBarTemplate@2x"] {
            if let url = url(name, extension: "png"),
               let data = try? Data(contentsOf: url),
               let representation = NSBitmapImageRep(data: data)
            {
                representation.size = image.size
                image.addRepresentation(representation)
            }
        }
        if image.representations.isEmpty {
            return NSImage(systemSymbolName: "sun.max", accessibilityDescription: "Helios") ?? image
        }
        image.isTemplate = true
        image.accessibilityDescription = "Helios"
        return image
    }()

    private static func url(_ name: String, extension fileExtension: String) -> URL? {
        let resources: Bundle? = if Bundle.main.bundleURL.pathExtension == "app" {
            // SwiftPM's generated accessor varies by toolchain and may only search
            // beside the executable. App bundles keep resources in Contents/Resources.
            Bundle.main.url(forResource: "Helios_Helios", withExtension: "bundle")
                .flatMap(Bundle.init(url:))
        } else {
            Bundle.module
        }
        return resources?.url(forResource: name, withExtension: fileExtension, subdirectory: "Resources/Branding")
    }
}
