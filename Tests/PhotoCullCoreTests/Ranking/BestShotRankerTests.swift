import XCTest
@testable import PhotoCullCore

final class BestShotRankerTests: XCTestCase {
    let ranker = BestShotRanker()

    // MARK: - Helpers

    private func asset(
        id: String,
        width: Int = 100, height: Int = 100,
        isFavorite: Bool = false,
        isEdited: Bool = false,
        date: Date? = nil
    ) -> PhotoAsset {
        PhotoAsset(
            id: id,
            creationDate: date,
            pixelWidth: width,
            pixelHeight: height,
            isFavorite: isFavorite,
            isEdited: isEdited
        )
    }

    /// Features with all signals populated (no suppression from Rule B).
    private func fullFeatures(
        assetId: String,
        sharpness: Double = 0.5,
        exposure: Double = 0.5,
        subject: Double = 0.5
    ) -> AssetFeatures {
        AssetFeatures(
            assetId: assetId,
            featureVector: FeatureVector(values: [1, 0]),
            sharpnessScore: SharpnessScore(value: sharpness),
            exposureScore: exposure,
            subjectScore: subject
        )
    }

    /// Features with nil optional signals (triggers Rule B).
    private func partialFeatures(assetId: String, sharpness: Double = 0.5) -> AssetFeatures {
        AssetFeatures(
            assetId: assetId,
            featureVector: FeatureVector(values: [1, 0]),
            sharpnessScore: SharpnessScore(value: sharpness)
        )
    }

    private func makeGroup(members: [PhotoAsset], reason: GroupingReason = .nearDuplicate) throws -> CullGroup {
        try CullGroup(reason: reason, members: members)
    }

    private func confirmedPair(a: String, b: String, score: Double = 0.05) -> CandidatePair {
        CandidatePair(assetIdA: a, assetIdB: b, prefilterReason: .timeProximity, similarityScore: score)
    }

    private func makeConfig(confidenceThreshold: Double = 0.60) -> CullConfiguration {
        var config = CullConfiguration.default
        config.confidenceThreshold = confidenceThreshold
        return config
    }

    private func assetMap(_ assets: [PhotoAsset]) -> [String: PhotoAsset] {
        Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) })
    }

    // MARK: - Favorite always kept regardless of composite score

    func testFavoriteAlwaysKeptRegardlessOfCompositeScore() throws {
        let fav = asset(id: "fav", isFavorite: true)
        let sharp = asset(id: "sharp", width: 4000, height: 4000) // highest resolution
        let members = [fav, sharp]
        let group = try makeGroup(members: members)
        let features: [String: AssetFeatures] = [
            "fav":   fullFeatures(assetId: "fav", sharpness: 0.1, exposure: 0.1, subject: 0.1),
            "sharp": fullFeatures(assetId: "sharp", sharpness: 0.99, exposure: 0.99, subject: 0.99)
        ]
        let recs = ranker.rank(
            group: group, features: features, pairs: [],
            assets: assetMap(members), configuration: makeConfig()
        )
        let keeper = recs.first(where: { $0.action == .keep })
        XCTAssertEqual(keeper?.asset.id, "fav", "Favorite must be kept regardless of composite score")
    }

    // MARK: - Edited beats better-quality raw (Tier 1 > Tier 2)

    func testEditedBeatsBetterQualityRaw() throws {
        let edited = asset(id: "edited", isEdited: true)
        let raw = asset(id: "raw")
        let members = [edited, raw]
        let group = try makeGroup(members: members)
        let features: [String: AssetFeatures] = [
            "edited": fullFeatures(assetId: "edited", sharpness: 0.2, exposure: 0.2, subject: 0.2),
            "raw":    fullFeatures(assetId: "raw", sharpness: 0.99, exposure: 0.99, subject: 0.99)
        ]
        let recs = ranker.rank(
            group: group, features: features, pairs: [],
            assets: assetMap(members), configuration: makeConfig()
        )
        let keeper = recs.first(where: { $0.action == .keep })
        XCTAssertEqual(keeper?.asset.id, "edited", "Edited (Tier 1) must beat better-quality raw (Tier 2)")
    }

    // MARK: - Multiple favorites: composite score breaks tie

    func testMultipleFavoritesCompositeScoreBreaksTie() throws {
        let fav1 = asset(id: "fav1", isFavorite: true)
        let fav2 = asset(id: "fav2", isFavorite: true)
        let members = [fav1, fav2]
        let group = try makeGroup(members: members)
        let features: [String: AssetFeatures] = [
            "fav1": fullFeatures(assetId: "fav1", sharpness: 0.3, exposure: 0.3, subject: 0.3),
            "fav2": fullFeatures(assetId: "fav2", sharpness: 0.9, exposure: 0.9, subject: 0.9)
        ]
        let recs = ranker.rank(
            group: group, features: features, pairs: [],
            assets: assetMap(members), configuration: makeConfig()
        )
        let keeper = recs.first(where: { $0.action == .keep })
        XCTAssertEqual(keeper?.asset.id, "fav2", "Among favorites, best composite score must win")
    }

    // MARK: - Missing signals on cull candidate → cull suppressed (Rule B)

    func testMissingSignalsOnCullCandidateSuppressesCull() throws {
        let a = asset(id: "a")
        let b = asset(id: "b")
        let members = [a, b]
        let group = try makeGroup(members: members)
        let features: [String: AssetFeatures] = [
            "a": fullFeatures(assetId: "a", sharpness: 0.9, exposure: 0.9, subject: 0.9),
            "b": partialFeatures(assetId: "b", sharpness: 0.1) // nil exposure and subject
        ]
        let recs = ranker.rank(
            group: group, features: features, pairs: [],
            assets: assetMap(members), configuration: makeConfig()
        )
        let cullRecs = recs.filter { $0.action == .cull }
        XCTAssertTrue(cullRecs.isEmpty, "Cull candidate with missing signals must not be culled (Rule B)")
        XCTAssertEqual(recs.filter { $0.action == .keep }.count, 2,
                       "Both members should be kept when cull is suppressed by Rule B")
    }

    // MARK: - Low confidence → cull suppressed (Rule A)

    func testLowConfidenceSuppressesCull() throws {
        // With confidenceThreshold = 1.0, all recommendations are suppressed
        let a = asset(id: "a")
        let b = asset(id: "b")
        let members = [a, b]
        let group = try makeGroup(members: members)
        let features: [String: AssetFeatures] = [
            "a": fullFeatures(assetId: "a", sharpness: 0.5, exposure: 0.5, subject: 0.5),
            "b": fullFeatures(assetId: "b", sharpness: 0.5, exposure: 0.5, subject: 0.5)
        ]
        var config = makeConfig()
        config.confidenceThreshold = 1.0  // impossible to meet → all culls suppressed

        let recs = ranker.rank(
            group: group, features: features, pairs: [],
            assets: assetMap(members), configuration: config
        )
        let cullRecs = recs.filter { $0.action == .cull }
        XCTAssertTrue(cullRecs.isEmpty, "All culls should be suppressed when threshold is 1.0 (Rule A)")
    }

    // MARK: - Both suppression rules: all members kept, SafetyGuard passes

    func testBothSuppressionsAllMembersKept() throws {
        // Rule B: missing signals. Keeper has full signals but cull candidate is partial.
        let a = asset(id: "a")
        let b = asset(id: "b")
        let members = [a, b]
        let group = try makeGroup(members: members)
        let features: [String: AssetFeatures] = [
            "a": fullFeatures(assetId: "a"),
            "b": partialFeatures(assetId: "b") // triggers Rule B
        ]
        let config = makeConfig(confidenceThreshold: 1.0) // also triggers Rule A for any remaining

        let recs = ranker.rank(
            group: group, features: features, pairs: [],
            assets: assetMap(members), configuration: config
        )
        XCTAssertTrue(recs.allSatisfy { $0.action == .keep },
                      "All members should be kept when both suppression rules apply")
        // SafetyGuard passes: at least one keeper
        XCTAssertTrue(SafetyGuard().isSafe(recs))
    }

    // MARK: - Signal breakdown populated on keeper

    func testKeeperHasSignalBreakdown() throws {
        let a = asset(id: "a")
        let b = asset(id: "b")
        let members = [a, b]
        let group = try makeGroup(members: members)
        let features: [String: AssetFeatures] = [
            "a": fullFeatures(assetId: "a", sharpness: 0.9, exposure: 0.8, subject: 0.7),
            "b": fullFeatures(assetId: "b", sharpness: 0.2, exposure: 0.2, subject: 0.2)
        ]
        let recs = ranker.rank(
            group: group, features: features, pairs: [],
            assets: assetMap(members), configuration: makeConfig()
        )
        let keeper = recs.first(where: { $0.action == .keep })
        XCTAssertNotNil(keeper?.signalBreakdown, "Keeper must have signalBreakdown")
        XCTAssertFalse(keeper?.signalBreakdown?.isEmpty ?? true, "Keeper signalBreakdown must not be empty")
    }

    // MARK: - Signal breakdown populated on culled member

    func testCulledMemberHasSignalBreakdown() throws {
        let a = asset(id: "a")
        let b = asset(id: "b")
        let members = [a, b]
        let group = try makeGroup(members: members)
        let features: [String: AssetFeatures] = [
            "a": fullFeatures(assetId: "a", sharpness: 0.9, exposure: 0.9, subject: 0.9),
            "b": fullFeatures(assetId: "b", sharpness: 0.1, exposure: 0.1, subject: 0.1)
        ]
        // Use a low threshold so cull is not suppressed by Rule A
        var config = makeConfig(confidenceThreshold: 0.0)
        config.confidenceThreshold = 0.0

        let recs = ranker.rank(
            group: group, features: features, pairs: [confirmedPair(a: "a", b: "b", score: 0.01)],
            assets: assetMap(members), configuration: config
        )
        let culled = recs.first(where: { $0.action == .cull })
        XCTAssertNotNil(culled?.signalBreakdown, "Culled member must have signalBreakdown")
    }

    // MARK: - Large group: exactly one keeper from highest tier

    func testLargeGroupHasExactlyOneKeeperFromHighestTier() throws {
        // 8 members; first is a favorite → must be the only keeper
        let favMember = asset(id: "fav", isFavorite: true)
        let others = (1...7).map { asset(id: "m\($0)") }
        let members = [favMember] + others
        let group = try CullGroup(reason: .burst, members: members)
        var features: [String: AssetFeatures] = [
            "fav": fullFeatures(assetId: "fav", sharpness: 0.1, exposure: 0.1, subject: 0.1)
        ]
        for m in others {
            features[m.id] = fullFeatures(assetId: m.id, sharpness: 0.9, exposure: 0.9, subject: 0.9)
        }
        // Low threshold so scores don't suppress culls for non-favorites
        var config = makeConfig(confidenceThreshold: 0.0)
        config.confidenceThreshold = 0.0

        let recs = ranker.rank(
            group: group, features: features, pairs: [],
            assets: assetMap(members), configuration: config
        )
        let keepers = recs.filter { $0.action == .keep }
        XCTAssertEqual(keepers.count, 1, "Exactly one keeper expected")
        XCTAssertEqual(keepers[0].asset.id, "fav", "Favorite must be the keeper")
        XCTAssertEqual(recs.count, members.count)
    }

    // MARK: - Tie-break by date then by id

    func testTieBreakByDateThenById() throws {
        let earlier = Date(timeIntervalSince1970: 1000)
        let later = Date(timeIntervalSince1970: 2000)
        let a = asset(id: "a", date: earlier)
        let b = asset(id: "b", date: later)
        let members = [a, b]
        let group = try makeGroup(members: members)
        let features: [String: AssetFeatures] = [
            "a": fullFeatures(assetId: "a", sharpness: 0.5, exposure: 0.5, subject: 0.5),
            "b": fullFeatures(assetId: "b", sharpness: 0.5, exposure: 0.5, subject: 0.5)
        ]
        let recs = ranker.rank(
            group: group, features: features, pairs: [],
            assets: assetMap(members), configuration: makeConfig()
        )
        let keeper = recs.first(where: { $0.action == .keep })
        // b has a later date → should be preferred
        XCTAssertEqual(keeper?.asset.id, "b", "Newer creation date should win tie-break")
    }

    func testTieBreakByIdWhenDatesEqual() throws {
        let date = Date(timeIntervalSince1970: 1000)
        let a = asset(id: "a", date: date)
        let b = asset(id: "b", date: date)
        let members = [a, b]
        let group = try makeGroup(members: members)
        let features: [String: AssetFeatures] = [
            "a": fullFeatures(assetId: "a", sharpness: 0.5, exposure: 0.5, subject: 0.5),
            "b": fullFeatures(assetId: "b", sharpness: 0.5, exposure: 0.5, subject: 0.5)
        ]
        let recs = ranker.rank(
            group: group, features: features, pairs: [],
            assets: assetMap(members), configuration: makeConfig()
        )
        let keeper = recs.first(where: { $0.action == .keep })
        // Lexicographically smallest id wins: "a" < "b"
        XCTAssertEqual(keeper?.asset.id, "a", "Lexicographically smallest id should win final tie-break")
    }
}
