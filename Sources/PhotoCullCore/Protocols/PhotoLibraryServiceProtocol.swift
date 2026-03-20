import Foundation

/// Abstracts access to the user's photo library.
/// Phase 1: MockPhotoLibraryService (synthetic data).
/// Phase 2 implementation: PhotoLibraryService (PHPhotoLibrary).
public protocol PhotoLibraryServiceProtocol: Sendable {
    func fetchAssets() async throws -> [PhotoAsset]
    func loadImageData(for asset: PhotoAsset) async throws -> Data
}
