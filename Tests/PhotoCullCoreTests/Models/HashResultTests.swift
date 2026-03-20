import XCTest
@testable import PhotoCullCore

final class HashResultTests: XCTestCase {
    func testStoresAssetAndHash() {
        let asset = PhotoAsset(id: "a1")
        let hash = Data("abc123".utf8)
        let result = HashResult(asset: asset, cryptoHash: hash)
        XCTAssertEqual(result.asset, asset)
        XCTAssertEqual(result.cryptoHash, hash)
    }

    func testEquality() {
        let asset = PhotoAsset(id: "a1")
        let hash = Data("abc".utf8)
        XCTAssertEqual(HashResult(asset: asset, cryptoHash: hash),
                       HashResult(asset: asset, cryptoHash: hash))
    }

    func testInequalityOnDifferentHash() {
        let asset = PhotoAsset(id: "a1")
        let r1 = HashResult(asset: asset, cryptoHash: Data("h1".utf8))
        let r2 = HashResult(asset: asset, cryptoHash: Data("h2".utf8))
        XCTAssertNotEqual(r1, r2)
    }
}
