import Foundation
import PhotoCullCore

/// Synthetic photo library for the app shell. Returns hardcoded assets to demonstrate the pipeline.
struct MockPhotoLibraryService: PhotoLibraryServiceProtocol {
    func fetchAssets() async throws -> [PhotoAsset] {
        [
            PhotoAsset(id: "asset-1", creationDate: Date(timeIntervalSinceNow: -100), isFavorite: true),
            PhotoAsset(id: "asset-2", creationDate: Date(timeIntervalSinceNow: -200)),
            PhotoAsset(id: "asset-3", creationDate: Date(timeIntervalSinceNow: -300)),
            PhotoAsset(id: "asset-4", creationDate: Date(timeIntervalSinceNow: -400), isEdited: true),
            PhotoAsset(id: "asset-5", creationDate: Date(timeIntervalSinceNow: -500)),
        ]
    }

    func loadImageData(for asset: PhotoAsset) async throws -> Data {
        // assets 1 and 2 share the same "image data" → exact duplicates
        // assets 4 and 5 share the same "image data" → another duplicate pair
        switch asset.id {
        case "asset-1", "asset-2": return Data("image-group-A".utf8)
        case "asset-4", "asset-5": return Data("image-group-B".utf8)
        default:                   return Data(asset.id.utf8)  // unique
        }
    }
}
