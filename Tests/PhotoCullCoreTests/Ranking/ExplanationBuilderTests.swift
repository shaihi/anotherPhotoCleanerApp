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

    // MARK: - Real keeper delta values in cull explanation

    func testCullExplanationUsesRealKeeperDeltaNotApproximation() throws {
        let a = PhotoAsset(id: "a")
        let b = PhotoAsset(id: "b")
        let group = try CullGroup(reason: .nearDuplicate, members: [a, b])

        // Keeper breakdown: sharpness = 0.90
        let keeperBreakdown: [String: Double] = ["sharpness": 0.90]
        // Cull candidate breakdown: sharpness = 0.30 → real delta = 0.60
        let cullBreakdown: [String: Double] = ["sharpness": 0.30]

        let cullRec = CullRecommendation(
            asset: b,
            action: .cull,
            reasons: [],
            confidence: 0.85,
            signalBreakdown: cullBreakdown
        )
        let explained = builder.explain(recommendation: cullRec, in: group, keeperBreakdown: keeperBreakdown)
        let text = explained.reasons.joined()
        // Should report real candidate value (0.30) and real keeper value (0.90), not approximation (0.30 + 0.2 = 0.50)
        XCTAssertTrue(text.contains("0.30"), "Cull explanation must contain real candidate value 0.30; got: \(text)")
        XCTAssertTrue(text.contains("0.90"), "Cull explanation must contain real keeper value 0.90; got: \(text)")
        XCTAssertFalse(text.contains("0.50"), "Cull explanation must not use approximated keeper value 0.50; got: \(text)")
    }

    // Test 11: Blur reason set by BestShotRanker is preserved through explain()
    // Uses the existing pass-through guard (if !recommendation.reasons.isEmpty { return recommendation.reasons })
    // to verify blur reasons survive ExplanationBuilder without modification.
    // No sharpness computation — reason string is injected directly into CullRecommendation.
    func testBlurReasonPreservedThroughExplain() throws {
        let nearDupGroup = try CullGroup(
            reason: .nearDuplicate,
            members: [PhotoAsset(id: "a"), PhotoAsset(id: "b")]
        )
        let blurReason = "Suggested for removal: likely accidental blur (sharpness 0.04 vs keeper 0.88)."
        let rec = CullRecommendation(
            asset: nearDupGroup.members[1],
            action: .cull,
            reasons: [blurReason],
            confidence: 0.80,
            signalBreakdown: ["sharpness": 0.04, "exposure": 0.70]
        )
        let explained = builder.explain(recommendation: rec, in: nearDupGroup)
        XCTAssertEqual(explained.reasons, [blurReason],
            "ExplanationBuilder must preserve blur reasons written by BestShotRanker; got: \(explained.reasons)")
    }
}
