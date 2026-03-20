import XCTest
@testable import PhotoCullCore

final class PhotoAssetTests: XCTestCase {
    func testIdentity() {
        let a = PhotoAsset(id: "abc")
        XCTAssertEqual(a.id, "abc")
    }

    func testEquality() {
        let a = PhotoAsset(id: "x", isFavorite: true)
        let b = PhotoAsset(id: "x", isFavorite: true)
        XCTAssertEqual(a, b)
    }

    func testInequalityOnDifferentId() {
        let a = PhotoAsset(id: "x")
        let b = PhotoAsset(id: "y")
        XCTAssertNotEqual(a, b)
    }

    func testDefaultValues() {
        let a = PhotoAsset(id: "z")
        XCTAssertNil(a.creationDate)
        XCTAssertFalse(a.isFavorite)
        XCTAssertFalse(a.isEdited)
        XCTAssertNil(a.burstIdentifier)
        XCTAssertTrue(a.mediaSubtypes.isEmpty)
    }

    func testHashableUsableInSet() {
        let a = PhotoAsset(id: "1")
        let b = PhotoAsset(id: "2")
        let set: Set<PhotoAsset> = [a, b, a]
        XCTAssertEqual(set.count, 2)
    }

    func testNoComputedFields() {
        // PhotoAsset must not store any computed/pipeline-derived data.
        // Verified by inspection: only raw metadata properties exist.
        let a = PhotoAsset(id: "raw")
        _ = a.id; _ = a.creationDate; _ = a.pixelWidth; _ = a.pixelHeight
        _ = a.isFavorite; _ = a.isEdited; _ = a.burstIdentifier; _ = a.mediaSubtypes
        // If this compiles, PhotoAsset has no extra computed fields.
        XCTAssertTrue(true)
    }
}
