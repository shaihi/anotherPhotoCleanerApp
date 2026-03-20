import CryptoKit
import Foundation

public struct CryptoHasher: Sendable {
    public init() {}

    /// Returns the SHA-256 digest of the given data.
    public func hash(_ data: Data) -> Data {
        let digest = SHA256.hash(data: data)
        return Data(digest)
    }
}
