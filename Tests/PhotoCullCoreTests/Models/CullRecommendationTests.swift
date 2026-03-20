import XCTest
@testable import PhotoCullCore

final class CullRecommendationTests: XCTestCase {
    func testDefaultNotOverridden() {
        let rec = CullRecommendation(
            asset: PhotoAsset(id: "a"),
            action: .keep,
            reasons: ["test"],
            confidence: 0.9
        )
        XCTAssertFalse(rec.isOverriddenByUser)
    }

    func testKeepAction() {
        let rec = CullRecommendation(asset: PhotoAsset(id: "a"), action: .keep, reasons: [], confidence: 1.0)
        XCTAssertEqual(rec.action, .keep)
    }

    func testCullAction() {
        let rec = CullRecommendation(asset: PhotoAsset(id: "a"), action: .cull, reasons: ["dup"], confidence: 0.9)
        XCTAssertEqual(rec.action, .cull)
    }
}
