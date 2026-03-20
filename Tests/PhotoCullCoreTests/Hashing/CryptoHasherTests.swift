import XCTest
@testable import PhotoCullCore

final class CryptoHasherTests: XCTestCase {
    let hasher = CryptoHasher()

    func testDeterministic() {
        let data = Data("hello world".utf8)
        XCTAssertEqual(hasher.hash(data), hasher.hash(data))
    }

    func testDifferentDataProducesDifferentHash() {
        XCTAssertNotEqual(hasher.hash(Data("a".utf8)), hasher.hash(Data("b".utf8)))
    }

    func testOutputIsSHA256Length() {
        // SHA-256 is 32 bytes
        let hash = hasher.hash(Data("test".utf8))
        XCTAssertEqual(hash.count, 32)
    }

    func testEmptyDataIsHashable() {
        let hash = hasher.hash(Data())
        XCTAssertEqual(hash.count, 32)
    }

    func testLargeDataIsHashable() {
        let data = Data(repeating: 0xAB, count: 10_000)
        let hash = hasher.hash(data)
        XCTAssertEqual(hash.count, 32)
    }

    func testIdenticalDataProducesSameHash() {
        let data = Data("image-bytes".utf8)
        let a = hasher.hash(data)
        let b = hasher.hash(data)
        XCTAssertEqual(a, b)
    }
}
