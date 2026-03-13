import AppKit

@MainActor
final class AppearanceAwareView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.masksToBounds = true
        updateBackground()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackground()
    }

    private func updateBackground() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
    }
}
