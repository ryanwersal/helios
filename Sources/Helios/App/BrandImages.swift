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
        image.isTemplate = true
        image.accessibilityDescription = "Helios"
        return image
    }()

    private static func url(_ name: String, extension fileExtension: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: fileExtension, subdirectory: "Resources/Branding")
    }
}
