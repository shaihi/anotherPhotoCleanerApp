import AppKit

/// Provides on-demand thumbnail images for photo assets.
/// `NullThumbnailProvider` is used by default in Phase 5 since PhotoKit
/// integration is not yet in scope. Rendering falls back to a placeholder slot.
protocol ThumbnailProvider: Sendable {
    func thumbnail(for assetId: String) async -> NSImage?
}

struct NullThumbnailProvider: ThumbnailProvider {
    func thumbnail(for assetId: String) async -> NSImage? { nil }
}
