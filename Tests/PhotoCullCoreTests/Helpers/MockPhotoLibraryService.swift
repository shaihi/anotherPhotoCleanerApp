import Foundation
@testable import PhotoCullCore

final class MockPhotoLibraryService: PhotoLibraryServiceProtocol, @unchecked Sendable {
    var assets: [PhotoAsset]
    var imageDataMap: [String: Data]  // assetId → Data
    var defaultData: Data

    init(
        assets: [PhotoAsset] = [],
        imageDataMap: [String: Data] = [:],
        defaultData: Data = Data("default".utf8)
    ) {
        self.assets = assets
        self.imageDataMap = imageDataMap
        self.defaultData = defaultData
    }

    func fetchAssets() async throws -> [PhotoAsset] { assets }

    func loadImageData(for asset: PhotoAsset) async throws -> Data {
        imageDataMap[asset.id] ?? defaultData
    }
}
