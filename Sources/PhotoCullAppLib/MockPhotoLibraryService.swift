import Foundation
import PhotoCullCore

/// Synthetic photo library for the app shell.
///
/// Uses real sport photos bundled in MockImages/ to simulate a near-duplicate scenario:
/// - archery-1 + archery-2: two shots of the same archery scene (near-duplicate pair)
/// - billiards-1 + billiards-2: two shots of the same billiards scene (near-duplicate pair)
/// - swimming-1: clearly different scene (unique, no pair)
///
/// All assets have unique bytes — duplicates are detected by visual similarity (near-duplicate
/// pipeline), not by SHA hash, matching how burst photos behave in a real photo library.
struct MockPhotoLibraryService: PhotoLibraryServiceProtocol {
    func fetchAssets() async throws -> [PhotoAsset] {
        let now = Date()
        return [
            // Archery near-duplicate pair — 3 seconds apart, simulating burst
            PhotoAsset(id: "archery-1", creationDate: now.addingTimeInterval(-7200)),
            PhotoAsset(id: "archery-2", creationDate: now.addingTimeInterval(-7197)),
            // Unique photo — clearly different scene
            PhotoAsset(id: "swimming-1", creationDate: now.addingTimeInterval(-3600)),
            // Billiards near-duplicate pair — 2 seconds apart, simulating burst
            PhotoAsset(id: "billiards-1", creationDate: now.addingTimeInterval(-1800)),
            PhotoAsset(id: "billiards-2", creationDate: now.addingTimeInterval(-1798)),
        ]
    }

    func loadImageData(for asset: PhotoAsset) async throws -> Data {
        let filename = asset.id  // e.g. "archery-1" → "archery-1.jpg"
        guard let url = Bundle.module.url(forResource: filename, withExtension: "jpg",
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
