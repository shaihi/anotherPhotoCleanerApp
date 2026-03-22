import Foundation
import PhotoCullCore

/// Synthetic photo library for the app shell.
///
/// Uses four variants of the same archery photo to simulate a near-duplicate burst group:
/// - archery-orig:       original JPEG at 100% quality
/// - archery-compressed: same pixels, re-encoded at 90% JPEG quality
/// - archery-dark:       brightness reduced by 10% (simulates exposure variation)
/// - archery-sharp:      one pass of unsharp mask (simulates in-camera sharpening)
///
/// All four have different bytes but identical visual content → near-duplicate detection
/// should group them, exactly as it would for real burst or HDR-bracket photos.
/// swimming-1 is a clearly different scene with no pair.
struct MockPhotoLibraryService: PhotoLibraryServiceProtocol {
    func fetchAssets() async throws -> [PhotoAsset] {
        let now = Date()
        return [
            // Four near-duplicate variants — timestamps simulate a 3-second burst
            PhotoAsset(id: "archery-orig",       creationDate: now.addingTimeInterval(-7200)),
            PhotoAsset(id: "archery-compressed", creationDate: now.addingTimeInterval(-7199)),
            PhotoAsset(id: "archery-dark",       creationDate: now.addingTimeInterval(-7198)),
            PhotoAsset(id: "archery-sharp",      creationDate: now.addingTimeInterval(-7197)),
            // Unique — clearly different scene, should not be grouped
            PhotoAsset(id: "swimming-1",         creationDate: now.addingTimeInterval(-3600)),
        ]
    }

    func loadImageData(for asset: PhotoAsset) async throws -> Data {
        guard let url = Bundle.module.url(forResource: asset.id, withExtension: "jpg",
                                          subdirectory: "MockImages") else {
            throw MockServiceError.imageNotFound(asset.id)
        }
        return try Data(contentsOf: url)
    }
}

private enum MockServiceError: Error, LocalizedError {
    case imageNotFound(String)
    var errorDescription: String? {
        if case .imageNotFound(let id) = self { return "Mock image not found for asset '\(id)'" }
        return nil
    }
}
