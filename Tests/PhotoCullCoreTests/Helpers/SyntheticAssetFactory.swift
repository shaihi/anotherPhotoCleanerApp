import Foundation
@testable import PhotoCullCore

enum SyntheticAssetFactory {
    static func asset(
        id: String = UUID().uuidString,
        creationDate: Date? = nil,
        isFavorite: Bool = false,
        isEdited: Bool = false
    ) -> PhotoAsset {
        PhotoAsset(
            id: id,
            creationDate: creationDate,
            isFavorite: isFavorite,
            isEdited: isEdited
        )
    }

    static func hashResult(asset: PhotoAsset, hashSeed: String) -> HashResult {
        HashResult(asset: asset, cryptoHash: Data(hashSeed.utf8))
    }

    /// Returns N assets that all share the same hash (i.e., exact duplicates).
    static func duplicateSet(count: Int, hashSeed: String = "shared-hash") -> [HashResult] {
        (0..<count).map { i in
            let asset = asset(id: "dup-\(hashSeed)-\(i)")
            return HashResult(asset: asset, cryptoHash: Data(hashSeed.utf8))
        }
    }
}
