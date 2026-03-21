import XCTest
@testable import PhotoCullCore

final class SimilarityRankerTests: XCTestCase {
    let ranker = SimilarityRanker()

    // MARK: - Helpers

    private func asset(
        id: String,
        isFavorite: Bool = false,
        isEdited: Bool = false,
        date: Date? = nil
    ) -> PhotoAsset {
        PhotoAsset(id: id, creationDate: date, isFavorite: isFavorite, isEdited: isEdited)
    }

    private func features(assetId: String, sharpness: Double, vector: [Float] = [1, 0]) -> AssetFeatures {
        AssetFeatures(
            assetId: assetId,
            featureVector: FeatureVector(values: vector),
            sharpnessScore: SharpnessScore(value: sharpness)
        )
    }

    private func makeGroup(members: [PhotoAsset]) throws -> CullGroup {
        try CullGroup(reason: .nearDuplicate, members: members)
    }

    private func confirmedPair(a: String, b: String, score: Double) -> CandidatePair {
        CandidatePair(assetIdA: a, assetIdB: b, prefilterReason: .timeProximity, similarityScore: score)
    }

    // MARK: - Sharpness ranking

    func testSharpestPhotoIsKept() throws {
        let sharp = asset(id: "sharp")
        let blurry = asset(id: "blurry")
        let group = try makeGroup(members: [sharp, blurry])
        let featMap: [String: AssetFeatures] = [
            "sharp": features(assetId: "sharp", sharpness: 0.9),
            "blurry": features(assetId: "blurry", sharpness: 0.3),
        ]
        let recs = ranker.rank(group: group, features: featMap, pairs: [])
        let keeper = recs.first(where: { $0.action == .keep })
        XCTAssertEqual(keeper?.asset.id, "sharp")
    }

    // MARK: - Favorite priority

    func testFavoriteBeatsSharpestNonFavorite() throws {
        let fav = asset(id: "fav", isFavorite: true)
        let sharp = asset(id: "sharp")
        let group = try makeGroup(members: [fav, sharp])
        let featMap: [String: AssetFeatures] = [
            "fav": features(assetId: "fav", sharpness: 0.2),    // blurry but favorite
            "sharp": features(assetId: "sharp", sharpness: 0.9),
        ]
        let recs = ranker.rank(group: group, features: featMap, pairs: [])
        let keeper = recs.first(where: { $0.action == .keep })
        XCTAssertEqual(keeper?.asset.id, "fav", "Favorite must win regardless of sharpness")
    }

    // MARK: - Edited priority

    func testEditedBeatsSharpestNonEditedNonFavorite() throws {
        let edited = asset(id: "edited", isEdited: true)
        let sharpRaw = asset(id: "raw")
        let group = try makeGroup(members: [edited, sharpRaw])
        let featMap: [String: AssetFeatures] = [
            "edited": features(assetId: "edited", sharpness: 0.4),
            "raw": features(assetId: "raw", sharpness: 0.95),
        ]
        let recs = ranker.rank(group: group, features: featMap, pairs: [])
        let keeper = recs.first(where: { $0.action == .keep })
        XCTAssertEqual(keeper?.asset.id, "edited", "Edited photo must beat sharper non-edited non-favorite")
    }

    // MARK: - Multiple favorites: sharpness breaks tie

    func testMultipleFavoritesSharpestWins() throws {
        let fav1 = asset(id: "fav1", isFavorite: true)
        let fav2 = asset(id: "fav2", isFavorite: true)
        let group = try makeGroup(members: [fav1, fav2])
        let featMap: [String: AssetFeatures] = [
            "fav1": features(assetId: "fav1", sharpness: 0.5),
            "fav2": features(assetId: "fav2", sharpness: 0.9),
        ]
        let recs = ranker.rank(group: group, features: featMap, pairs: [])
        let keeper = recs.first(where: { $0.action == .keep })
        XCTAssertEqual(keeper?.asset.id, "fav2", "Among favorites, sharpest must win")
    }

    // MARK: - Confidence is derived, not flat

    func testConfidenceValuesAreDerived() throws {
        let a = asset(id: "a")
        let b = asset(id: "b")
        let group = try makeGroup(members: [a, b])
        let featMap: [String: AssetFeatures] = [
            "a": features(assetId: "a", sharpness: 0.8),
            "b": features(assetId: "b", sharpness: 0.3),
        ]
        // Pair with very low distance → high confidence
        let pairs = [confirmedPair(a: "a", b: "b", score: 0.02)]
        let recs = ranker.rank(group: group, features: featMap, pairs: pairs)
        let keepConf = recs.first(where: { $0.action == .keep })?.confidence ?? 0
        let cullConf = recs.first(where: { $0.action == .cull })?.confidence ?? 0

        // Both confidences should be above 0.5 (clamped minimum)
        XCTAssertGreaterThan(keepConf, 0.5)
        XCTAssertGreaterThan(cullConf, 0.5)
        // Keep should have higher or equal confidence than cull (rankSeparationBonus ≥ 0.8)
        XCTAssertGreaterThanOrEqual(keepConf, cullConf)
        // Confidences must not exceed 0.95
        XCTAssertLessThanOrEqual(keepConf, 0.95)
        XCTAssertLessThanOrEqual(cullConf, 0.95)
    }

    func testConfidenceReflectsPairDistance() throws {
        let a = asset(id: "a")
        let b = asset(id: "b")
        let groupClose = try makeGroup(members: [a, b])
        let groupFar = try makeGroup(members: [a, b])
        let featMap: [String: AssetFeatures] = [
            "a": features(assetId: "a", sharpness: 0.8),
            "b": features(assetId: "b", sharpness: 0.8),
        ]
        let closeScore = 0.01
        let farScore = 0.13
        let recsClose = ranker.rank(group: groupClose, features: featMap,
                                    pairs: [confirmedPair(a: "a", b: "b", score: closeScore)])
        let recsFar = ranker.rank(group: groupFar, features: featMap,
                                  pairs: [confirmedPair(a: "a", b: "b", score: farScore)])
        let confClose = recsClose.first(where: { $0.action == .keep })?.confidence ?? 0
        let confFar = recsFar.first(where: { $0.action == .keep })?.confidence ?? 0
        // Closer pairs should yield higher confidence.
        XCTAssertGreaterThanOrEqual(confClose, confFar)
    }

    // MARK: - Large group

    func testLargeGroupHasExactlyOneKeeper() throws {
        let members = (0..<6).map { asset(id: "m\($0)") }
        let group = try CullGroup(reason: .burst, members: members)
        var featMap: [String: AssetFeatures] = [:]
        for (i, m) in members.enumerated() {
            featMap[m.id] = features(assetId: m.id, sharpness: Double(i) * 0.1)
        }
        let pairs = (0..<5).map { confirmedPair(a: "m\($0)", b: "m\($0+1)", score: 0.03) }
        let recs = ranker.rank(group: group, features: featMap, pairs: pairs)
        let keepers = recs.filter { $0.action == .keep }
        XCTAssertEqual(keepers.count, 1)
        XCTAssertEqual(recs.count, members.count)
    }

    // MARK: - Two-member group

    func testTwoMemberGroupProducesOneKeepOneCull() throws {
        let a = asset(id: "a")
        let b = asset(id: "b")
        let group = try makeGroup(members: [a, b])
        let featMap: [String: AssetFeatures] = [
            "a": features(assetId: "a", sharpness: 0.7),
            "b": features(assetId: "b", sharpness: 0.4),
        ]
        let recs = ranker.rank(group: group, features: featMap, pairs: [])
        XCTAssertEqual(recs.count, 2)
        XCTAssertEqual(recs.filter { $0.action == .keep }.count, 1)
        XCTAssertEqual(recs.filter { $0.action == .cull }.count, 1)
    }
}
