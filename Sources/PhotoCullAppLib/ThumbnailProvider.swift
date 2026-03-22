import AppKit
import PhotoCullCore

/// Provides on-demand thumbnail images for photo assets.
protocol ThumbnailProvider: Sendable {
    func thumbnail(for assetId: String) async -> NSImage?
}

/// Always returns nil. Used in unit tests only — never in a running app.
struct NullThumbnailProvider: ThumbnailProvider {
    func thumbnail(for assetId: String) async -> NSImage? { nil }
}

/// Loads thumbnails from a `PhotoLibraryServiceProtocol` by calling `loadImageData(for:)`
/// and converting the result to NSImage. This ensures the thumbnail and the hash/feature
/// pipeline both see the same bytes — the source of truth is the service, not a separate path.
struct ServiceBackedThumbnailProvider: ThumbnailProvider {
    private let service: any PhotoLibraryServiceProtocol

    init(service: any PhotoLibraryServiceProtocol) {
        self.service = service
    }

    func thumbnail(for assetId: String) async -> NSImage? {
        let asset = PhotoAsset(id: assetId)
        guard let data = try? await service.loadImageData(for: asset) else { return nil }
        return NSImage(data: data)
    }
}
