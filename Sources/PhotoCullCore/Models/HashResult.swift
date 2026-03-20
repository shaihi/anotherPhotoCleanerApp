import Foundation

public struct HashResult: Sendable, Equatable {
    public let asset: PhotoAsset
    public let cryptoHash: Data   // SHA-256 of full-resolution image bytes

    public init(asset: PhotoAsset, cryptoHash: Data) {
        self.asset = asset
        self.cryptoHash = cryptoHash
    }
}
