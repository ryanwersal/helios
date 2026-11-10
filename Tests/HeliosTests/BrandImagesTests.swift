import AppKit
@testable import Helios
import Testing

@MainActor
struct BrandImagesTests {
    @Test
    func `app icon is available from packaged resources`() throws {
        let icon = try #require(BrandImages.appIcon)
        #expect(icon.isValid)
        #expect(!icon.representations.isEmpty)
    }

    @Test
    func `menu icon has visible transparent standard and retina representations`() throws {
        let icon = BrandImages.menuBarIcon
        #expect(icon.isTemplate)
        #expect(icon.size == NSSize(width: 18, height: 18))
        #expect(icon.accessibilityDescription == "Helios")
        let representations = icon.representations.compactMap { $0 as? NSBitmapImageRep }
        #expect(representations.map(\.pixelsWide).sorted() == [18, 36])
        for representation in representations {
            #expect(representation.hasAlpha)
            #expect(representation.size == icon.size)
            let corner = try #require(representation.colorAt(x: 0, y: 0))
            #expect(corner.alphaComponent < 0.1)
            let visiblePixels = (0 ..< representation.pixelsWide).flatMap { column in
                (0 ..< representation.pixelsHigh).compactMap { row in
                    representation.colorAt(x: column, y: row)?.alphaComponent
                }
            }.filter { $0 > 0.5 }
            #expect(visiblePixels.count > representation.pixelsWide)
        }
    }
}
