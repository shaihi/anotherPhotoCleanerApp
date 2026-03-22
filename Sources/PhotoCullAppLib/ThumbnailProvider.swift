import AppKit

/// Provides on-demand thumbnail images for photo assets.
protocol ThumbnailProvider: Sendable {
    func thumbnail(for assetId: String) async -> NSImage?
}

/// Always returns nil. Used in unit tests only — never in a running app.
struct NullThumbnailProvider: ThumbnailProvider {
    func thumbnail(for assetId: String) async -> NSImage? { nil }
}

/// Generates a distinct colored placeholder image for each asset ID.
/// Used in the mock app shell so every thumbnail slot shows visible content
/// without requiring real photo library access.
struct MockThumbnailProvider: ThumbnailProvider {
    func thumbnail(for assetId: String) async -> NSImage? {
        let size = CGSize(width: 200, height: 200)
        return NSImage(size: size, flipped: false) { rect in
            // Stable hue derived from the asset ID so each asset gets a unique color.
            let hue = CGFloat(abs(assetId.hashValue % 360)) / 360
            NSColor(hue: hue, saturation: 0.45, brightness: 0.78, alpha: 1).setFill()
            rect.fill()

            let text = assetId as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .font: NSFont.boldSystemFont(ofSize: 13)
            ]
            let strSize = text.size(withAttributes: attrs)
            let origin = CGPoint(
                x: (rect.width - strSize.width) / 2,
                y: (rect.height - strSize.height) / 2
            )
            text.draw(at: origin, withAttributes: attrs)
            return true
        }
    }
}
