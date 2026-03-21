import XCTest
@testable import PhotoCullCore

final class SimilarityGroupBuilderTests: XCTestCase {
    let builder = SimilarityGroupBuilder()

    // Convenience: make a confirmed pair (with a dummy similarityScore).
    private func confirmedPair(
        a: String, b: String,
        reason: PrefilterReason = .timeProximity
    ) -> CandidatePair {
        CandidatePair(assetIdA: a, assetIdB: b, prefilterReason: reason, similarityScore: 0.05)
    }

    private func asset(id: String, burstId: String? = nil) -> PhotoAsset {
        PhotoAsset(id: id, burstIdentifier: burstId)
    }

    // MARK: - Basic grouping

    func testSinglePairProducesOneGroup() throws {
        let pairs = [confirmedPair(a: "a", b: "b")]
        let assetMap = ["a": asset(id: "a"), "b": asset(id: "b")]
        let groups = builder.buildGroups(from: pairs, assets: assetMap)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].members.count, 2)
    }

    func testTransitivePairsFormOneGroup() throws {
        // a-b and b-c should merge into one group {a, b, c}.
        let pairs = [confirmedPair(a: "a", b: "b"), confirmedPair(a: "b", b: "c")]
        let assetMap = ["a": asset(id: "a"), "b": asset(id: "b"), "c": asset(id: "c")]
        let groups = builder.buildGroups(from: pairs, assets: assetMap)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].members.count, 3)
    }

    func testDisjointPairsProduceTwoGroups() throws {
        let pairs = [confirmedPair(a: "a", b: "b"), confirmedPair(a: "c", b: "d")]
        let assetMap = [
            "a": asset(id: "a"), "b": asset(id: "b"),
            "c": asset(id: "c"), "d": asset(id: "d"),
        ]
        let groups = builder.buildGroups(from: pairs, assets: assetMap)
        XCTAssertEqual(groups.count, 2)
    }

    // MARK: - Grouping reason

    func testBurstReasonWhenAllShareBurstId() {
        let pairs = [confirmedPair(a: "a", b: "b", reason: .burstId)]
        let assetMap = [
            "a": asset(id: "a", burstId: "burst-1"),
            "b": asset(id: "b", burstId: "burst-1"),
        ]
        let groups = builder.buildGroups(from: pairs, assets: assetMap)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].reason, .burst)
    }

    func testNearDuplicateReasonForNoBurstId() {
        let pairs = [confirmedPair(a: "a", b: "b", reason: .timeProximity)]
        let assetMap = [
            "a": asset(id: "a"),
            "b": asset(id: "b"),
        ]
        let groups = builder.buildGroups(from: pairs, assets: assetMap)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].reason, .nearDuplicate)
    }

    func testNearDuplicateReasonWhenBurstIdsDiffer() {
        let pairs = [confirmedPair(a: "a", b: "b", reason: .burstId)]
        let assetMap = [
            "a": asset(id: "a", burstId: "burst-1"),
            "b": asset(id: "b", burstId: "burst-2"),  // different burst
        ]
        let groups = builder.buildGroups(from: pairs, assets: assetMap)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].reason, .nearDuplicate)
    }

    // MARK: - Edge cases

    func testEmptyPairsProducesNoGroups() {
        XCTAssertTrue(builder.buildGroups(from: [], assets: [:]).isEmpty)
    }

    func testSingletonComponentsDropped() {
        // A pair where one asset is missing from the asset map → component of size 1.
        let pairs = [confirmedPair(a: "a", b: "missing")]
        let assetMap = ["a": asset(id: "a")]
        let groups = builder.buildGroups(from: pairs, assets: assetMap)
        XCTAssertTrue(groups.isEmpty, "Components with <2 members should be dropped")
    }
}
