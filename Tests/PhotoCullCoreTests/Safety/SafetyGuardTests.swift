import XCTest
@testable import PhotoCullCore

final class SafetyGuardTests: XCTestCase {
    let guard_ = SafetyGuard()

    func makeGroup(count: Int = 2) throws -> CullGroup {
        let members = (0..<count).map { PhotoAsset(id: "m\($0)") }
        return try CullGroup(reason: .exactDuplicate, members: members)
    }

    func makeCullRecommendation(asset: PhotoAsset) -> CullRecommendation {
        CullRecommendation(asset: asset, action: .cull, reasons: ["dup"], confidence: 0.9)
    }

    func makeKeepRecommendation(asset: PhotoAsset) -> CullRecommendation {
        CullRecommendation(asset: asset, action: .keep, reasons: ["best"], confidence: 0.9)
    }

    func testValidInputPassesThrough() throws {
        let group = try makeGroup()
        let recs = [
            makeKeepRecommendation(asset: group.members[0]),
            makeCullRecommendation(asset: group.members[1]),
        ]
        let result = try guard_.validate(recommendations: recs, for: group)
        XCTAssertEqual(result[0].action, .keep)
        XCTAssertEqual(result[1].action, .cull)
    }

    func testAllCullForcesFirstToKeep() throws {
        let group = try makeGroup(count: 3)
        let recs = group.members.map { makeCullRecommendation(asset: $0) }
        let result = try guard_.validate(recommendations: recs, for: group)
        let keeps = result.filter { $0.action == .keep }
        XCTAssertEqual(keeps.count, 1)
        XCTAssertEqual(result[0].action, .keep)
        XCTAssertEqual(result[1].action, .cull)
    }

    func testForcedKeepIncludesSafetyReason() throws {
        let group = try makeGroup()
        let recs = group.members.map { makeCullRecommendation(asset: $0) }
        let result = try guard_.validate(recommendations: recs, for: group)
        XCTAssertTrue(result[0].reasons.contains(where: { $0.contains("Safety") }))
    }

    func testEmptyRecommendationsThrows() throws {
        let group = try makeGroup()
        XCTAssertThrowsError(try guard_.validate(recommendations: [], for: group)) { error in
            XCTAssertEqual(error as? SafetyViolation, SafetyViolation.emptyRecommendations)
        }
    }

    func testSingleKeepPassesThrough() throws {
        let group = try makeGroup()
        let recs = [makeKeepRecommendation(asset: group.members[0])]
        let result = try guard_.validate(recommendations: recs, for: group)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].action, .keep)
    }

    func testNeverAllCullInOutput() throws {
        // Adversarial: all recs are .cull
        let group = try makeGroup(count: 5)
        let allCull = group.members.map { makeCullRecommendation(asset: $0) }
        let result = try guard_.validate(recommendations: allCull, for: group)
        XCTAssertTrue(result.contains(where: { $0.action == .keep }))
    }

    func testRecommendationAssetNotInGroupThrows() throws {
        let group = try makeGroup(count: 2)
        let outsideAsset = PhotoAsset(id: "notInGroup")
        let recs = [makeCullRecommendation(asset: outsideAsset)]
        XCTAssertThrowsError(try guard_.validate(recommendations: recs, for: group)) { error in
            XCTAssertEqual(error as? SafetyViolation, SafetyViolation.recommendationAssetNotInGroup(assetId: "notInGroup"))
        }
    }

    func testIsSafeReturnsTrueWhenKeepExists() {
        let asset = PhotoAsset(id: "a")
        let recs = [
            makeKeepRecommendation(asset: asset),
            makeCullRecommendation(asset: PhotoAsset(id: "b")),
        ]
        XCTAssertTrue(guard_.isSafe(recs))
    }

    func testIsSafeReturnsFalseWhenAllCull() {
        let recs = [
            makeCullRecommendation(asset: PhotoAsset(id: "a")),
            makeCullRecommendation(asset: PhotoAsset(id: "b")),
        ]
        XCTAssertFalse(guard_.isSafe(recs))
    }
}
