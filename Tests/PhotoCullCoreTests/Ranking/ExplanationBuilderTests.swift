import XCTest
@testable import PhotoCullCore

final class ExplanationBuilderTests: XCTestCase {
    let builder = ExplanationBuilder()

    func makeGroup() throws -> CullGroup {
        try CullGroup(reason: .exactDuplicate, members: [PhotoAsset(id: "a"), PhotoAsset(id: "b")])
    }

    func testCullRecommendationHasNonEmptyReasons() throws {
        let group = try makeGroup()
        let rec = CullRecommendation(asset: group.members[1], action: .cull, reasons: [], confidence: 0.9)
        let explained = builder.explain(recommendation: rec, in: group)
        XCTAssertFalse(explained.reasons.isEmpty)
    }

    func testKeepRecommendationHasNonEmptyReasons() throws {
        let group = try makeGroup()
        let rec = CullRecommendation(asset: group.members[0], action: .keep, reasons: [], confidence: 0.9)
        let explained = builder.explain(recommendation: rec, in: group)
        XCTAssertFalse(explained.reasons.isEmpty)
    }

    func testFavoriteKeptMentionsFavorite() throws {
        let fav = PhotoAsset(id: "fav", isFavorite: true)
        let other = PhotoAsset(id: "other")
        let group = try CullGroup(reason: .exactDuplicate, members: [fav, other])
        let rec = CullRecommendation(asset: fav, action: .keep, reasons: [], confidence: 0.9)
        let explained = builder.explain(recommendation: rec, in: group)
        XCTAssertTrue(explained.reasons.joined().lowercased().contains("favorite"))
    }

    func testCullReasonMentionsDuplicate() throws {
        let group = try makeGroup()
        let rec = CullRecommendation(asset: group.members[1], action: .cull, reasons: [], confidence: 0.9)
        let explained = builder.explain(recommendation: rec, in: group)
        XCTAssertTrue(explained.reasons.joined().lowercased().contains("duplicate"))
    }

    func testOtherFieldsPreserved() throws {
        let group = try makeGroup()
        let rec = CullRecommendation(asset: group.members[0], action: .keep, reasons: [], confidence: 0.77)
        let explained = builder.explain(recommendation: rec, in: group)
        XCTAssertEqual(explained.confidence, 0.77)
        XCTAssertEqual(explained.action, .keep)
        XCTAssertEqual(explained.asset, group.members[0])
    }
}
